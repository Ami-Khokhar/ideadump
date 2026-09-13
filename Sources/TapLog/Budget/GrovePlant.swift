import SwiftUI

/// Three placeholder species, all currently rendered from the shared TreeArt family
/// and differentiated only by layout until Phase 2 authors distinct silhouettes.
enum TreeSpecies: CaseIterable, Sendable, Equatable {
    case rounded
    case columnar
    case spreading
}

/// Sparse bloom state: meaning consistency or recovery, not a reward currency.
enum BloomState: Sendable, Equatable {
    case none
    case budding
    case flowering
}

/// One budgeted category laid out as a drawable plant in the grove scene.
///
/// All position and shape fields are normalized (0...1) and deterministic from
/// the category key, so the grove never rearranges between renders. Each plant
/// carries everything the scene renderer needs to place it on the ground, scale it,
/// tint it, and describe it to VoiceOver.
struct GrovePlant: Identifiable, Equatable, Sendable {
    /// Immutable identity: the category key this plant represents.
    let categoryKey: String

    /// Silhouette shape. All three currently share TreeArt and differ only in
    /// layout scaling; Phase 2 will author distinct geometry per species.
    let species: TreeSpecies

    /// Current tree health mark — one of six drawable states.
    let health: TreeHealthMark

    /// Position along the ground, 0 = left edge, 1 = right edge.
    /// Derived from categoryKey hash plus index offset to spread plants evenly.
    let normalizedX: CGFloat

    /// Depth staging: 0 = back (smaller, farther), 1 = front (larger, nearer).
    /// Also key-derived so plants stay in consistent z-order.
    let depth: CGFloat

    /// Maturity scaling: combines health (seedling small, resting/growing tall)
    /// with small key-seeded jitter. Clamped to 0...1.
    let height: CGFloat

    /// Color: clay when over budget, accent otherwise. Matches GroveTree.tint.
    let tint: Color

    /// Sparse bloom: flowering only for growing health, budding for sprout,
    /// none otherwise. Keeps flowers meaningful and not ubiquitous.
    let bloom: BloomState

    /// Accessibility summary: the tree's complete state description for VoiceOver.
    let accessibilitySummary: String

    /// Unique identity key for view diffing.
    var id: String { categoryKey }
}
