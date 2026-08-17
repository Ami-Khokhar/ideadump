import Foundation
import SwiftData

/// Locates the shared SwiftData store. The store lives in the App Group container so the
/// widget and share-extension targets (M3/M4) can read and write the same data. If the
/// group container isn't available (e.g. free Apple ID without the entitlement), it falls
/// back to on-device Application Support storage so the app always runs.
enum StoreLocator {
    static let appGroupID = "group.com.example.taplog"
    static let storeFileName = "TapLog.store"

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(
                for: Entry.self, SpendCategory.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static var storeURL: URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL.appendingPathComponent(storeFileName)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent(storeFileName)
    }
}
