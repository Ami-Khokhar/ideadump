import XCTest
@testable import TapLog

/// Every shipped target carries a privacy manifest, and each declaration matches
/// a required-reason API the target actually uses. The only such API here is
/// `UserDefaults`: the App Group suite shared by the app, the widget and the
/// share extension, and each process's own `.standard` defaults. Nothing in the
/// code compiled into these targets touches file timestamps, disk space, system
/// boot time or active keyboards, so no other category is declared.
final class PrivacyManifestTests: XCTestCase {
    /// Paths as they sit in the repository, one per shipped target.
    private static let manifests = [
        "Sources/TapLog/PrivacyInfo.xcprivacy",
        "Sources/TapLogWidget/PrivacyInfo.xcprivacy",
        "Sources/TapLogShare/PrivacyInfo.xcprivacy",
    ]

    /// .../Tests/TapLogTests/PrivacyManifestTests.swift -> the repository root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func plist(at path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(path))
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(parsed as? [String: Any], "\(path) is not a plist dictionary")
    }

    func testEveryShippedTargetHasAManifest() throws {
        for path in Self.manifests {
            XCTAssertNoThrow(try plist(at: path), "\(path) is missing or unreadable")
        }
    }

    func testNoTargetTracksOrCollectsData() throws {
        for path in Self.manifests {
            let manifest = try plist(at: path)
            XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false, path)
            XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [Any])?.count, 0, path)
            XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0, path)
        }
    }

    func testUserDefaultsReasonsMatchActualUse() throws {
        for path in Self.manifests {
            let manifest = try plist(at: path)
            let types = try XCTUnwrap(
                manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]],
                "\(path) has no NSPrivacyAccessedAPITypes"
            )
            let defaults = try XCTUnwrap(
                types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" },
                "\(path) does not declare the UserDefaults category"
            )
            let reasons = Set(try XCTUnwrap(
                defaults["NSPrivacyAccessedAPITypeReasons"] as? [String],
                "\(path) has no reasons"
            ))
            // 1C8F.1: defaults read by another app in the same App Group.
            // CA92.1: the app's own defaults, its own suite, its own process.
            XCTAssertEqual(reasons, ["1C8F.1", "CA92.1"], path)
        }
    }

    func testNoCategoryIsDeclaredThatNothingUses() throws {
        let used: Set<String> = ["NSPrivacyAccessedAPICategoryUserDefaults"]
        for path in Self.manifests {
            let manifest = try plist(at: path)
            let types = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]], path)
            for type in types {
                let name = try XCTUnwrap(type["NSPrivacyAccessedAPIType"] as? String, path)
                XCTAssertTrue(used.contains(name), "\(path) declares \(name), which nothing in that target uses")
            }
        }
    }

    /// The shipped target names, taken from the manifest paths so the two lists
    /// cannot drift: `Sources/<Target>/PrivacyInfo.xcprivacy`.
    private var shippedTargets: [String] {
        Self.manifests.compactMap { path in
            let parts = path.split(separator: "/")
            return parts.count >= 3 ? String(parts[1]) : nil
        }
    }

    /// The body of the pbxproj block that starts at `marker` and ends at the next
    /// top-level object close.
    private func pbxBlock(_ pbxproj: String, _ marker: String) -> String? {
        guard let start = pbxproj.range(of: marker)?.upperBound,
              let end = pbxproj.range(of: "\n\t\t};", range: start..<pbxproj.endIndex) else {
            return nil
        }
        return String(pbxproj[start..<end.lowerBound])
    }

    /// The manifests only ship if the generated project copies one into each
    /// target — the files on disk would still look correct without it. This
    /// checks the wiring per target, so a failure names the target that lost its
    /// manifest. Mirrors the entitlement-wiring guard in `StoreLocatorTests`.
    func testEveryShippedTargetResourcesPhaseCopiesItsManifest() throws {
        let pbxproj = try String(
            contentsOf: repoRoot.appendingPathComponent("TapLog.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        for target in shippedTargets {
            let targetBlock = try XCTUnwrap(
                pbxBlock(pbxproj, "/* \(target) */ = {\n\t\t\tisa = PBXNativeTarget;"),
                "no PBXNativeTarget block for \(target)"
            )
            let phaseLine = try XCTUnwrap(
                targetBlock.components(separatedBy: "\n").first { $0.contains("/* Resources */,") },
                "\(target) has no Resources build phase"
            )
            let phaseID = phaseLine.trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first.map(String.init) ?? ""
            XCTAssertFalse(phaseID.isEmpty, "could not read \(target)'s Resources phase id")
            let phaseBlock = try XCTUnwrap(
                pbxBlock(pbxproj, "\(phaseID) /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;"),
                "no Resources phase block for \(target)"
            )
            XCTAssertTrue(
                phaseBlock.contains("PrivacyInfo.xcprivacy in Resources"),
                "\(target)'s Resources phase does not copy its PrivacyInfo.xcprivacy — run xcodegen after editing project.yml"
            )
        }
    }
}
