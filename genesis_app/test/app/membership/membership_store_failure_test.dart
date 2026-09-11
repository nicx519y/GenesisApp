import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_store_failure.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  for (final (number, code, text) in [
    (-3, 'serviceTimeout', 'took too long'),
    (-2, 'featureNotSupported', 'not supported'),
    (-1, 'serviceDisconnected', 'connection to Google Play was lost'),
    (1, 'userCanceled', 'Premium purchase canceled.'),
    (2, 'serviceUnavailable', 'temporarily unavailable'),
    (3, 'billingUnavailable', 'payment settings'),
    (4, 'itemUnavailable', 'Premium subscription is currently unavailable'),
    (5, 'developerError', 'could not start this subscription'),
    (6, 'error', 'could not complete this Premium purchase'),
    (7, 'itemAlreadyOwned', 'already own this subscription'),
    (8, 'itemNotOwned', 'could not find the subscription to change'),
    (12, 'networkError', 'internet connection'),
  ]) {
    test(
      'Google code $number resolves numeric, launch, query and stream representations',
      () {
        for (final error in [
          PlatformException(code: '$number'),
          PlatformException(code: code),
          IAPError(
            source: 'google_play',
            code: code,
            message: 'raw debug message',
          ),
          IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: 'BillingResponse.$code',
          ),
        ]) {
          final result = membershipStoreFailure(
            MembershipProvider.google,
            error,
          )!;
          expect(result.message, contains(text));
          expect(result.canceled, number == 1);
        }
      },
    );
  }
  test('Google subcodes override generic failures, never OK/cancellation', () {
    for (final (subcode, text) in [
      (1, 'insufficient funds'),
      (2, 'not eligible'),
    ]) {
      expect(
        membershipStoreError(
          MembershipProvider.google,
          code: 'error',
          details: {'subResponseCode': subcode},
        ).message,
        contains(text),
      );
    }
    expect(
      membershipStoreError(
        MembershipProvider.google,
        code: 'userCanceled',
        details: {'subResponseCode': 2},
      ).message,
      'Premium purchase canceled.',
    );
    expect(
      membershipStoreError(
        MembershipProvider.google,
        code: 'ok',
        details: {'subResponseCode': 2},
      ).code,
      'ok',
    );
    expect(
      membershipStoreError(
        MembershipProvider.google,
        code: 'developerError',
        details: {'subResponseCode': 999},
      ).message,
      contains('could not start'),
    );
  });

  for (final code in [
    'unknown',
    'userCancelled',
    'networkError',
    'systemError',
    'notAvailableInStorefront',
    'notEntitled',
    'unsupported',
    'invalidPresentationContext',
    'invalidQuantity',
    'productUnavailable',
    'purchaseNotAllowed',
    'ineligibleForOffer',
    'invalidOfferIdentifier',
    'invalidOfferPrice',
    'invalidOfferSignature',
    'missingOfferParameters',
    'paymentMethodBindingConfigurationRequired',
  ]) {
    test('Apple typed $code survives a generic Pigeon exception', () {
      final result = membershipStoreFailure(
        MembershipProvider.apple,
        PlatformException(
          code: 'raw error description',
          details: {'storeKitCode': code},
        ),
      )!;
      expect(membershipAppleErrorMessages, contains(result.code));
      expect(result.canceled, code == 'userCancelled');
    });
  }
  for (var number = 0; number <= 21; number++) {
    test(
      'Apple SKErrorDomain $number maps numeric codes only within its domain',
      () {
        final result = membershipStoreError(
          MembershipProvider.apple,
          code: 'purchase_error',
          details: {'domain': 'SKErrorDomain', 'nativeCode': number},
        );
        expect(membershipAppleErrorMessages, contains(result.code));
        expect(result.canceled, number == 2 || number == 15);
        final otherDomain = membershipStoreError(
          MembershipProvider.apple,
          code: 'purchase_error',
          details: {'domain': 'OtherDomain', 'nativeCode': number},
        );
        expect(otherDomain.code, 'purchase_error');
      },
    );
  }
  test('Apple system error inspects underlying network or SKError', () {
    expect(
      membershipStoreError(
        MembershipProvider.apple,
        details: {
          'storeKitCode': 'system_error',
          'underlyingDomain': 'NSURLErrorDomain',
          'underlyingCode': '-1001',
        },
      ).message,
      contains('took too long'),
    );
    expect(
      membershipStoreError(
        MembershipProvider.apple,
        details: {
          'storeKitCode': 'system_error',
          'underlyingDomain': 'SKErrorDomain',
          'underlyingCode': '18',
        },
      ).message,
      contains('not eligible'),
    );
    expect(
      membershipStoreError(
        MembershipProvider.apple,
        details: {'storeKitCode': 'notEntitled'},
      ).message,
      'This app cannot make this App Store request. Please contact support.',
    );
    expect(
      membershipStoreError(
        MembershipProvider.apple,
        details: {
          'storeKitCode': 'userCancelled',
          'underlyingDomain': 'NSURLErrorDomain',
          'underlyingCode': '-1001',
        },
      ).message,
      'Premium purchase canceled.',
    );
  });
  test(
    'unknown native codes have platform-specific fallback without guessing subscription state',
    () {
      expect(
        membershipStoreError(MembershipProvider.google, code: '1234').message,
        'Google Play could not complete this Premium purchase. Please try again.',
      );
      expect(
        membershipStoreError(
          MembershipProvider.apple,
          code: 'new_error',
        ).message,
        'The App Store could not complete this Premium purchase. Please try again.',
      );
      expect(
        membershipStoreFailure(
          MembershipProvider.apple,
          StateError('report failed'),
        ),
        isNull,
      );
    },
  );
}
