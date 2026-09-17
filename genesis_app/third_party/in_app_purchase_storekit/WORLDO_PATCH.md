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

## Expired subscription purchase gate

The upstream duplicate-product check also matches expired, unfinished subscription
renewals. Worldo skips a same-product unfinished transaction only when both the
queried product and that verified transaction are auto-renewable subscriptions, and the old
transaction's `expirationDate <= signedDate`. Apple's verified signing time proves
that billing period has ended; the decision does not use the device clock. Missing
expiry or a signature from before expiry preserves the original duplicate guard.
Every unfinished transaction is checked, so an expired renewal cannot hide a
later unfinished period that still blocks purchase. Other product types retain
the original guard, including consumable Gems.

This gate does not finish, report, claim, delete, or emit the skipped historical
transaction. `Transaction.unfinished` queries, receipt recovery, verification,
handoff authorization, and purchase-result delivery are unchanged. In particular,
expiry is not proof of backend settlement or ownership, and the old receipt stays
available for authorized recovery. The new purchase still goes through StoreKit
and the existing backend report/claim flow before entitlement is granted.

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
