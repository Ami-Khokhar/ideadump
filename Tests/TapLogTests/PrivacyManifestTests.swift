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

    /// The shipped target names, taken from the manifest paths. A path that does
    /// not have the expected shape fails the suite rather than silently shrinking
    /// the check to nothing.
    private func shippedTargets() -> [String] {
        Self.manifests.compactMap { path in
            let parts = path.split(separator: "/")
            guard parts.count == 3, parts[0] == "Sources", parts[2] == "PrivacyInfo.xcprivacy" else {
                XCTFail("manifest path is not Sources/<Target>/PrivacyInfo.xcprivacy: \(path)")
                return nil
            }
            return String(parts[1])
        }
    }

    /// The target names declared in project.yml, minus the unit-test bundle.
    private func declaredTargets() throws -> [String] {
        let yaml = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8
        )
        var names: [String] = []
        var inTargets = false
        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if line == "targets:" { inTargets = true; continue }
            guard inTargets else { continue }
            if trimmed.isEmpty { continue }
            if !line.hasPrefix(" ") { break }
            // A target name sits at two-space indent and ends with a colon.
            if line.hasPrefix("  "), !line.hasPrefix("   "), line.hasSuffix(":") {
                names.append(String(trimmed.dropLast()))
            }
        }
        return names
    }

    /// The body of the pbxproj block that starts at the regular-expression
    /// `marker` and ends at the next top-level object close. Whitespace is
    /// tolerated, so a formatting change in xcodegen's output does not read as a
    /// missing block.
    private func pbxBlock(_ pbxproj: String, marker: String) -> String? {
        guard let match = pbxproj.range(of: marker, options: .regularExpression) else { return nil }
        let tail = pbxproj[match.upperBound...]
        guard let end = tail.range(of: #"\n[ \t]*\};"#, options: .regularExpression) else { return nil }
        return String(tail[..<end.lowerBound])
    }

    /// The manifests only ship if the generated project copies one into each
    /// target — the files on disk would still look correct without it. Checks
    /// that every target in project.yml is covered, that each target's Resources
    /// phase copies its own distinct manifest, and names the target on failure.
    /// Mirrors the entitlement-wiring guard in `StoreLocatorTests`.
    func testEveryShippedTargetResourcesPhaseCopiesItsManifest() throws {
        let pbxproj = try String(
            contentsOf: repoRoot.appendingPathComponent("TapLog.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let shipped = shippedTargets()
        XCTAssertEqual(shipped.count, Self.manifests.count, "every manifest path must name a target")
        let declared = try declaredTargets()
        XCTAssertEqual(
            Set(declared).subtracting(["TapLogTests"]).sorted(),
            Set(shipped).sorted(),
            "project.yml targets and PrivacyManifestTests.manifests disagree — add the missing target to the list"
        )

        var buildFileByTarget: [String: String] = [:]
        for target in shipped {
            let targetBlock = try XCTUnwrap(
                pbxBlock(pbxproj, marker: "/\\* \(target) \\*/ = \\{\\s*\\n\\s*isa = PBXNativeTarget;"),
                "no PBXNativeTarget block for \(target) (or the pbxproj format changed)"
            )
            let phaseLine = try XCTUnwrap(
                targetBlock.components(separatedBy: "\n").first { $0.contains("/* Resources */,") },
                "\(target) has no Resources build phase"
            )
            let phaseID = phaseLine.trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first.map(String.init) ?? ""
            XCTAssertFalse(phaseID.isEmpty, "could not read \(target)'s Resources phase id")
            let phaseBlock = try XCTUnwrap(
                pbxBlock(pbxproj, marker: "\(phaseID) /\\* Resources \\*/ = \\{\\s*\\n\\s*isa = PBXResourcesBuildPhase;"),
                "no Resources phase block for \(target) (or the pbxproj format changed)"
            )
            guard let line = phaseBlock.components(separatedBy: "\n")
                .first(where: { $0.contains("PrivacyInfo.xcprivacy in Resources") }),
                let buildFileID = line.trimmingCharacters(in: .whitespaces)
                    .split(separator: " ").first.map(String.init) else {
                XCTFail("\(target)'s Resources phase does not copy its PrivacyInfo.xcprivacy — run xcodegen after editing project.yml")
                continue
            }
            buildFileByTarget[target] = buildFileID
        }
        XCTAssertEqual(
            Set(buildFileByTarget.values).count,
            shipped.count,
            "each shipped target must copy its own manifest build file; got \(buildFileByTarget)"
        )
    }
}
