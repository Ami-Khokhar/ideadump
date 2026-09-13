import SwiftUI

/// Pure derivation of the grove scene. A GroveScene renders these plants laid
/// out on a ground. Kept out of the view so the rules that decide species,
/// position, and bloom state are testable without standing up SwiftUI.
enum GroveSceneModel {

    // MARK: - Hashing

    /// Deterministic FNV-1a hash of a UTF-8 string.
    ///
    /// Returns a UInt64 hash stable across launches, suitable for seeding
    /// per-plant position and species derivation. Same input always produces
    /// the same hash.
    private static func hash(string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037  // FNV offset basis (64-bit)
        let prime: UInt64 = 1099511628211         // FNV prime (64-bit)
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    /// Deterministic CGFloat in [0, 1) derived from a string key.
    ///
    /// Used to seed position, depth, and height jitter. Always returns the
    /// same value for the same input.
    private static func seededValue(from key: String) -> CGFloat {
        let hashValue = hash(string: key)
        return CGFloat(hashValue % 10000) / 10000.0
    }

    // MARK: - Layout

    /// Plants laid out for the grove scene, one per GroveTree up to `maxPlants`.
    ///
    /// Trees are expected ordered most-pressed-first (highest utilization).
    /// Species, position, and jitter are deterministic from categoryKey hash,
    /// so the grove never rearranges between renders.
    ///
    /// - Parameters:
    ///   - trees: GroveTree list, ordered most-pressed-first.
    ///   - maxPlants: Maximum plants to render (default 7).
    /// - Returns: Array of GrovePlant, one per tree, up to maxPlants. Same
    ///   key always yields identical species and position.
    static func plants(from trees: [GroveTree], maxPlants: Int = 7) -> [GrovePlant] {
        return trees.prefix(maxPlants).enumerated().map { index, tree in
            let keyHash = hash(string: tree.categoryKey)

            // Species: derived from hash, one of three equally.
            let speciesIndex = Int(keyHash % 3)
            let species = TreeSpecies.allCases[speciesIndex]

            // Normalized X: spread evenly across the ground with key-seeded offset.
            let slotCount = min(trees.count, maxPlants)
            let baseSlot = slotCount > 1
                ? CGFloat(index) / CGFloat(slotCount - 1)
                : 0.5
            let offsetKey = "\(tree.categoryKey)-x"
            let offset = (seededValue(from: offsetKey) - 0.5) * 0.15  // ±7.5%
            let normalizedX = max(0, min(1, baseSlot + offset))

            // Depth: key-seeded, so same category always has same z-order.
            let depthKey = "\(tree.categoryKey)-depth"
            let depth = seededValue(from: depthKey)

            // Height maturity: health-based scale plus small jitter.
            let healthHeight: CGFloat
            switch tree.mark {
            case .noBudget:  healthHeight = 0.2
            case .seedling:  healthHeight = 0.3
            case .sprout:    healthHeight = 0.5
            case .growing:   healthHeight = 0.8
            case .wilting:   healthHeight = 0.6
            case .resting:   healthHeight = 0.7
            }
            let heightKey = "\(tree.categoryKey)-height"
            let jitter = (seededValue(from: heightKey) - 0.5) * 0.1  // ±5%
            let height = max(0, min(1, healthHeight + jitter))

            // Bloom: sparse, meaning consistent with health.
            let bloom: BloomState
            switch tree.mark {
            case .growing:   bloom = .flowering
            case .sprout:    bloom = .budding
            default:         bloom = .none
            }

            return GrovePlant(
                categoryKey: tree.categoryKey,
                species: species,
                health: tree.mark,
                normalizedX: normalizedX,
                depth: depth,
                height: height,
                tint: tree.tint,
                bloom: bloom,
                accessibilitySummary: tree.accessibilityLabel
            )
        }
    }

    // MARK: - Summary

    /// One concise VoiceOver sentence for the grove.
    ///
    /// Counts plants by health state and phrases the summary plainly.
    /// Handles zero and single plant gracefully. Example: "Four budget trees:
    /// three within target, one over."
    ///
    /// - Parameter plants: Array of GrovePlant from the scene.
    /// - Returns: One sentence suitable for VoiceOver announcement.
    static func summary(for plants: [GrovePlant]) -> String {
        guard !plants.isEmpty else { return "No budget trees." }

        let count = plants.count
        let treeWord = count == 1 ? "tree" : "trees"

        // Count plants within target: seedling, sprout, growing.
        let within = plants.filter { plant in
            switch plant.health {
            case .seedling, .sprout, .growing: return true
            default: return false
            }
        }.count

        // Count plants over target: wilting, resting.
        let over = plants.filter { plant in
            switch plant.health {
            case .wilting, .resting: return true
            default: return false
            }
        }.count

        if count == 1 {
            return "One budget \(treeWord)."
        }

        if over == 0 {
            return "\(count) budget \(treeWord): all within target."
        }

        if within == 0 {
            return "\(count) budget \(treeWord): all over target."
        }

        return "\(count) budget \(treeWord): \(within) within target, \(over) over."
    }
}
