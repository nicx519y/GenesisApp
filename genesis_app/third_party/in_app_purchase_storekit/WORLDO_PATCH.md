# Worldo StoreKit patch

Based on Flutter `in_app_purchase_storekit` 0.4.11+2 (BSD license in LICENSE).
Runtime and Pigeon sources are vendored at the resolved version; platform result
delivery, transaction verification, and transaction finishing retain upstream behavior.

The optional `Sk2PurchaseParam.onStoreHandoff` callback runs after native product
lookup and unfinished-transaction checks, immediately before `Product.purchase`.
A per-call `handoffId` travels in purchase options and a method-channel handshake
asks the owning checkout to proceed. False, unknown, or expired callbacks prevent
launch. The id is local IPC metadata, never an App Store option or backend field.

The callback means control is handed to StoreKit; Apple does not supply a separate
confirmation-sheet-visible callback here. The purchase Future still returns its
original result after user interaction. The app must not apply its preparation
deadline during that interaction.

Pigeon source and both generated purchase-option codecs include the trailing
optional `handoffId`; regenerate both together when updating upstream.

## Subscription purchase delegation

Auto-renewable subscriptions call `Product.purchase` without scanning or blocking
on `Transaction.unfinished`. StoreKit decides the outcome, including existing
subscriptions. Non-subscription products, including consumable Gems, keep their
original unfinished-transaction guard. This change does not finish or report
historical transactions, alter entitlement, or bypass the preparation deadline.

Apple and Google subscription callbacks share one report operation. Any business
status ends it. Transient connection/timeouts and HTTP 408/429/5xx allow at most
three immediate attempts with the same receipt; no report queue or restart retry
is created. Guest ownership proof remains available only for login/claim.

Membership store settlement is server-owned on both platforms: Apple uses App
Store Server API Finish Transaction; Google uses subscription acknowledgement.
The app does not call the plugin's transaction-finishing API after report or
claim. The plugin retains its upstream API for compatibility. The backend must
durably track and retry settlement after verification and entitlement delivery;
this client change does not establish that the deployed backend implements it.

Debug builds log the `Product.purchase` result category without receipts or
account tokens. Membership also logs callback timing and identity-match booleans
to distinguish a returned historical transaction from a missing callback. After
the Apple purchase Future returns, membership bounds the remaining unmatched
callback wait to 10 seconds; time spent inside Apple's purchase UI is unchanged.

Native regression checks compile and execute the production decision:

```sh
xcrun swiftc -module-cache-path /private/tmp/worldo-storekit-module-cache third_party/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/StoreKit2/StoreKitUnfinishedTransaction.swift test/native/storekit_unfinished_transactions/main.swift -o /private/tmp/worldo-storekit-unfinished-tests
/private/tmp/worldo-storekit-unfinished-tests
```

Run `pod install --deployment` in `ios/` and rebuild the iOS app after this native
change; hot reload cannot load the new gate. The Podspec and Swift package both
include the new Swift source through their existing source discovery rules.
