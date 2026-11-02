import Foundation

var state = StoreKitStorefrontState()
precondition(!state.initialized)
let initialVersion = state.updateVersion
precondition(!state.receiveInitial("US", version: initialVersion))
precondition(state.id == "US")
precondition(!state.receiveUpdate("US"))
precondition(state.receiveUpdate("JP"))
precondition(state.id == "JP")
precondition(!state.receiveInitial("US", version: initialVersion))
precondition(state.id == "JP")
precondition(state.receiveUpdate(nil))
precondition(!state.receiveUpdate(nil))
precondition(state.receiveUpdate("GB"))

var eventFirst = StoreKitStorefrontState()
let oldVersion = eventFirst.updateVersion
precondition(eventFirst.receiveUpdate("JP"))
precondition(!eventFirst.receiveInitial("US", version: oldVersion))
precondition(eventFirst.id == "JP")
precondition(eventFirst.receiveUpdate("US"))
print("Storefront cache: startup, event ordering, region change and account removal passed")
