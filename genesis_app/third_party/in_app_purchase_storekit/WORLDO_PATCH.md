# Worldo StoreKit patch

## Purchase debug traces

Debug builds emit `[StoreKit][purchase_trace]` with a per-call handoff ID,
product ID, native stage and elapsed milliseconds. Stages cover Dart launch,
native entry/product lookup, signature validation, handoff request/decision,
`Product.purchase` invocation/return, result dispatch and bridge completion.
Errors include NSError domain/code only, never receipts, tokens or account UUIDs.
`storekit_purchase_call` confirms invocation, not confirmation-sheet visibility.
Changes to native traces require rebuilding the iOS app; hot reload is insufficient.

Based on Flutter `in_app_purchase_storekit` 0.4.11+2 (BSD license in LICENSE).
Runtime and Pigeon sources are vendored at the resolved version; platform result
delivery, transaction verification, and transaction finishing retain upstream behavior.

The optional `Sk2PurchaseParam.onStoreHandoff` callback runs after native product
lookup and purchase-term validation, immediately before `Product.purchase`.
A per-call `handoffId` travels in purchase options and a method-channel handshake
asks the owning checkout to proceed. False, unknown, or expired callbacks prevent
launch. The id is local IPC metadata, never an App Store option or backend field.

The callback means control is handed to StoreKit; Apple does not supply a separate
confirmation-sheet-visible callback here. The purchase Future still returns its
original result after user interaction. The app must not apply its preparation
deadline during that interaction.

Pigeon source and both generated purchase-option codecs include the trailing
optional `handoffId`; regenerate both together when updating upstream.

## Purchase delegation

All StoreKit 2 products, including consumable Gems, call `Product.purchase`
without scanning or blocking on `Transaction.unfinished` before launch. StoreKit
decides the outcome. The server owns transaction settlement, including finish.
Transaction updates and unfinished-transaction recovery queries remain available;
this change does not finish or report historical transactions, alter entitlement,
or bypass product validation or the preparation deadline.

Apple and Google subscription callbacks report only on `purchased`, exactly once.
Pending, restored, canceled and failed callbacks never report. Any business status
or technical failure ends the operation, without immediate, Gateway, background
or restart retries. Only `completed` shows purchase success; report errors show
failure. Guest ownership proof remains available only for login/claim.

Membership store settlement is server-owned on both platforms: Apple uses App
Store Server API Finish Transaction; Google uses subscription acknowledgement.
The app does not call the plugin's transaction-finishing API after report or
claim. The plugin retains its upstream API for compatibility. The backend must
durably track and retry settlement after verification and entitlement delivery;
this client change does not establish that the deployed backend implements it.

Debug builds log the `Product.purchase` result category without receipts or
account tokens. Membership also logs callback timing and product/call correlation
to distinguish a returned historical transaction from a missing callback. After
the Apple purchase Future returns, membership bounds the remaining unmatched
callback wait to 10 seconds; time spent inside Apple's purchase UI is unchanged.

Direct purchase-result callbacks also carry an optional local `checkoutAttemptId`
through the generated codecs and Dart purchase objects. Background transaction
updates do not carry it. Membership uses it to end the originating checkout even
when StoreKit returns a previously reported transaction. A newly received direct
result is reported with its original proof even if its account token differs from
the requested UUID; the server decides ownership and entitlement. The correlation
id is not sent to Apple purchase options or the backend.

Regression checks cover StoreKit handoff, cache interfaces and Gems purchase
results:

```sh
flutter test test/platform/billing/storekit_purchase_handoff_test.dart test/platform/billing/storekit_product_cache_test.dart test/platform/billing/google_play_billing_service_test.dart
```

Run `pod install --deployment` in `ios/` and rebuild the iOS app after this native
change; hot reload cannot update the purchase path. The obsolete unfinished-gate
helper and its native checks have been removed.
