import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/server_clock.dart';
import 'app_event_reporting.dart';
import 'telemetry_upload_policy.dart';

enum PurchaseEventKind { gems, subscription }

abstract interface class PurchaseEventRecorder {
  Future<void> recordPurchase({
    required String provider,
    required String productId,
    required PurchaseEventKind kind,
    required String purchaseIdentity,
    String? transactionIdentity,
    int? priceAmountMicros,
    String priceCurrencyCode,
  });
}

abstract interface class PurchaseDay0AnchorStore {
  Future<DateTime?> read();

  Future<void> write(DateTime serverUtc);
}

class SharedPreferencesPurchaseDay0AnchorStore
    implements PurchaseDay0AnchorStore {
  const SharedPreferencesPurchaseDay0AnchorStore();

  // Keep the existing anchor across upgrades; it is a server timestamp, not
  // a Firebase event marker.
  static const storageKey = 'firebase_analytics_purchase_day0_anchor_utc_ms_v1';

  @override
  Future<DateTime?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final millis = preferences.getInt(storageKey);
    return millis == null || millis <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> write(DateTime serverUtc) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setInt(
      storageKey,
      serverUtc.toUtc().millisecondsSinceEpoch,
    )) {
      throw StateError('Failed to persist purchase Day0 anchor');
    }
  }
}

/// Sends store purchase events only to the Adjust S2S event endpoint.
/// Firebase Analytics is deliberately absent from this path.
class PurchaseEventReporting implements PurchaseEventRecorder {
  PurchaseEventReporting({
    required AppEventReporting eventReporting,
    required Future<String> Function() deviceIdReader,
    PurchaseDay0AnchorStore? day0AnchorStore,
    Future<bool> Function(String key)? legacyEventMarkerReader,
    ServerClock? serverClock,
    bool Function()? enabled,
  }) : _eventReporting = eventReporting,
       _deviceIdReader = deviceIdReader,
       _day0AnchorStore =
           day0AnchorStore ?? const SharedPreferencesPurchaseDay0AnchorStore(),
       _legacyEventMarkerReader =
           legacyEventMarkerReader ?? _readLegacyEventMarker,
       _serverClock = serverClock ?? ServerClock(),
       _enabled =
           enabled ??
           (() => TelemetryUploadPolicy.state.value.analyticsEnabled);

  final AppEventReporting _eventReporting;
  final Future<String> Function() _deviceIdReader;
  final PurchaseDay0AnchorStore _day0AnchorStore;
  final Future<bool> Function(String) _legacyEventMarkerReader;
  final ServerClock _serverClock;
  final bool Function() _enabled;
  DateTime? _day0AnchorUtc;
  Future<void>? _anchorInitialization;

  Future<void> recordServerTimeSynchronized(DateTime serverUtc) {
    final normalized = serverUtc.toUtc();
    _serverClock.synchronize(normalized);
    if (_day0AnchorUtc != null) return Future<void>.value();
    final current = _anchorInitialization;
    if (current != null) return current;
    late final Future<void> task;
    task =
        (() async {
          try {
            final stored = await _day0AnchorStore.read();
            if (stored == null) {
              await _day0AnchorStore.write(normalized);
            }
            _day0AnchorUtc = stored?.toUtc() ?? normalized;
          } catch (error) {
            debugPrint('[Telemetry][PurchaseEvent] Day0 anchor failed: $error');
            _day0AnchorUtc = null;
          }
        })().whenComplete(() {
          if (identical(_anchorInitialization, task)) {
            _anchorInitialization = null;
          }
        });
    _anchorInitialization = task;
    return task;
  }

  @override
  Future<void> recordPurchase({
    required String provider,
    required String productId,
    required PurchaseEventKind kind,
    required String purchaseIdentity,
    String? transactionIdentity,
    int? priceAmountMicros,
    String priceCurrencyCode = '',
  }) async {
    if (!_enabled() || purchaseIdentity.trim().isEmpty) return;
    final transactionId = (transactionIdentity ?? purchaseIdentity).trim();
    if (transactionId.isEmpty) return;
    // Google subscription renewals can change transaction_id while retaining
    // the purchase token. Keep the original receipt-based event identity.
    final receiptIdentity = sha256
        .convert(
          utf8.encode(
            jsonEncode(<String>[provider, kind.name, purchaseIdentity.trim()]),
          ),
        )
        .toString();
    final occurredAtSeconds =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerSecond;
    try {
      var deviceId = 'unknown';
      try {
        final value = (await _deviceIdReader()).trim();
        if (value.isNotEmpty) deviceId = value;
      } catch (_) {
        // Optional metadata cannot discard a store success.
      }
      final currency = priceCurrencyCode.trim().toUpperCase();
      final hasPrice =
          priceAmountMicros != null &&
          priceAmountMicros >= 0 &&
          RegExp(r'^[A-Z]{3}$').hasMatch(currency);
      final parameters = <String, Object>{
        'provider': provider,
        'product_id': productId,
        'device_id': deviceId,
        if (hasPrice) 'value': priceAmountMicros / 1000000,
        if (hasPrice) 'currency': currency,
      };
      final kindName = kind.name;
      final events = <String>[
        'purchase',
        kindName,
        'purchase_first',
        '${kindName}_first',
        if (await _isDay0()) ...[
          'purchase_day0',
          '${kindName}_day0',
          'purchase_first_day0',
          '${kindName}_first_day0',
        ],
      ];
      for (final event in events) {
        final legacyKey = AppEventReporting.firstPurchaseEvents.contains(event)
            ? event
            : '${event}_transaction_v1.$receiptIdentity';
        try {
          if (await _legacyEventMarkerReader(legacyKey)) continue;
        } catch (error) {
          debugPrint(
            '[Telemetry][PurchaseEvent] legacy event marker read failed: '
            '$error',
          );
        }
        await _eventReporting.report(
          event: event,
          occurredAtSeconds: occurredAtSeconds,
          parameters: parameters,
          transactionId: transactionId,
          transactionDeduplicationId: receiptIdentity,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Telemetry][PurchaseEvent] reporting failed: $error');
      debugPrint('[Telemetry][PurchaseEvent] stacktrace:\n$stackTrace');
    }
  }

  Future<bool> _isDay0() async {
    final initialization = _anchorInitialization;
    if (initialization != null) await initialization;
    final anchor = _day0AnchorUtc;
    final now = _serverClock.now?.toUtc();
    if (anchor == null || now == null || now.isBefore(anchor)) return false;
    const chinaOffset = Duration(hours: 8);
    final anchorChina = anchor.add(chinaOffset);
    final nowChina = now.add(chinaOffset);
    return anchorChina.year == nowChina.year &&
        anchorChina.month == nowChina.month &&
        anchorChina.day == nowChina.day;
  }

  static Future<bool> _readLegacyEventMarker(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt('firebase_analytics_once_event_v1.$key') == 1;
  }
}
