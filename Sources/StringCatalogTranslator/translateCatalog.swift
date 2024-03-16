//
// https://github.com/atacan
// 16.03.24
	

import Foundation
import StringCatalog

typealias funcTranslateType = (String, String?) async throws -> String

func translateCatalog(_ catalog: StringCatalog, to targetLanguage: StringLanguage, with translate: funcTranslateType) async throws -> StringCatalog {
    let catalogIsolated = MyActorIsolated(catalog)
    
    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in catalog.strings.indices {
            group.addTask {
                let key = catalog.strings.keys[index]
                let value = catalog.strings.values[index]
                try await catalogIsolated.withValue {
                    if $0.strings[key]?.localizations == nil {
                        let translation = try await translate(key, value.comment)
                        $0.strings[key]?.localizations = [targetLanguage: StringLocalization(stringUnit: .init(state: .translated, value: translation))]
                    } 
                    else if $0.strings[key]?.localizations?[targetLanguage] == nil {
                        let translation = try await translate(key, value.comment)
                        $0.strings[key]?.localizations?[targetLanguage] = StringLocalization(stringUnit: .init(state: .translated, value: translation))
                    }
//                    print("🥁", key, "👍", $0.strings[key]?.localizations?[targetLanguage])
                }
            }
        }
        
        try await group.waitForAll()
    }
    try await print(catalogIsolated.value.encodePrettyToString())
    return await catalogIsolated.value
}

//func translateCatalog(_ catalog: StringCatalog, to targetLanguage: StringLanguage, with translate: (String, String?) async throws -> String) async throws -> StringCatalog {
//    var newCatalog = catalog
//    
//    for (key, value) in newCatalog.strings {
//        if value.localizations == nil {
//            let translation = try await translate(key, value.comment)
//            newCatalog.strings[key]?.localizations = [targetLanguage: StringLocalization(stringUnit: .init(state: .translated, value: translation))]
//        } else if newCatalog.strings[key]?.localizations?[targetLanguage] == nil {
//            let translation = try await translate(key, value.comment)
//            newCatalog.strings[key]?.localizations?[targetLanguage] = StringLocalization(stringUnit: .init(state: .translated, value: translation))
//        }
//        // Note: Synchronous code does not print logs in-between tasks without explicit sleep/pause, that's usually a characteristic of asynchronous execution.
//        print("🥁", key, "👍", newCatalog.strings[key]?.localizations?[targetLanguage])
//    }
//
//    return newCatalog
//}

final actor MyActorIsolated<Value> {
  /// The actor-isolated value.
  var value: Value

  /// Initializes actor-isolated state around a value.
  ///
  /// - Parameter value: A value to isolate in an actor.
   init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
    self.value = try value()
  }

  /// Perform an operation with isolated access to the underlying value.
  ///
  /// Useful for modifying a value in a single transaction.
  ///
  /// ```swift
  /// // Isolate an integer for concurrent read/write access:
  /// let count = ActorIsolated(0)
  ///
  /// func increment() async {
  ///   // Safely increment it:
  ///   await self.count.withValue { $0 += 1 }
  /// }
  /// ```
  ///
  /// > Tip: Because XCTest assertions don't play nicely with Swift concurrency, `withValue` also
  /// > provides a handy interface to peek at an actor-isolated value and assert against it:
  /// >
  /// > ```swift
  /// > let didOpenSettings = ActorIsolated(false)
  /// > let model = withDependencies {
  /// >   $0.openSettings = { await didOpenSettings.setValue(true) }
  /// > } operation: {
  /// >   FeatureModel()
  /// > }
  /// > await model.settingsButtonTapped()
  /// > await didOpenSettings.withValue { XCTAssertTrue($0) }
  /// > ```
  ///
  /// - Parameter operation: An operation to be performed on the actor with the underlying value.
  /// - Returns: The result of the operation.
   func withValue<T>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }

  /// Overwrite the isolated value with a new value.
  ///
  /// ```swift
  /// // Isolate an integer for concurrent read/write access:
  /// let count = ActorIsolated(0)
  ///
  /// func reset() async {
  ///   // Reset it:
  ///   await self.count.setValue(0)
  /// }
  /// ```
  ///
  /// > Tip: Use ``withValue(_:)`` instead of `setValue` if the value being set is derived from the
  /// > current value. This isolates the entire transaction and avoids data races between reading
  /// > and writing the value.
  ///
  /// - Parameter newValue: The value to replace the current isolated value with.
   func setValue(_ newValue: @autoclosure @Sendable () throws -> Value) rethrows {
    self.value = try newValue()
  }
}
