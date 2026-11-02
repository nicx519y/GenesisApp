// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Region snapshot only. Product prices and purchase authorization remain in StoreKit.
struct StoreKitStorefrontState {
  private(set) var id: String?
  private(set) var initialized = false
  private(set) var updateVersion = 0

  /// A delayed startup read must not overwrite a more recent storefront event.
  mutating func receiveInitial(_ id: String?, version: Int) -> Bool {
    guard version == updateVersion, !initialized else { return false }
    self.id = id
    initialized = true
    return false
  }

  /// A change notification invalidates products, even before the initial read.
  mutating func receiveUpdate(_ id: String?) -> Bool {
    updateVersion += 1
    let changed = !initialized || self.id != id
    self.id = id
    initialized = true
    return changed
  }
}
