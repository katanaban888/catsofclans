import Foundation

/// Screen points = (world - center) * scale + viewport/2. No SwiftUI/CoreGraphics.
public struct MapCamera: Equatable {
    public let worldSize: V2
    public private(set) var viewport: V2
    public private(set) var center: V2
    /// Relative to fit-to-screen: 1 shows the entire map, 4 is close-up.
    public private(set) var zoom: Double
    public var scale: Double { min(viewport.x / worldSize.x, viewport.y / worldSize.y) * zoom }

    public init(worldSize: V2, viewport: V2, center: V2? = nil, zoom: Double = 1) {
        self.worldSize = V2(max(1, worldSize.x), max(1, worldSize.y))
        self.viewport = V2(max(1, viewport.x), max(1, viewport.y))
        self.center = center ?? worldSize * 0.5
        self.zoom = min(4, max(1, zoom.isFinite ? zoom : 1))
        clampCenter()
    }

    public func worldToScreen(_ point: V2) -> V2 {
        (point - center) * scale + viewport * 0.5
    }

    public func screenToWorld(_ point: V2) -> V2 {
        (point - viewport * 0.5) * (1 / scale) + center
    }

    public mutating func resize(_ size: V2) {
        guard size.x.isFinite, size.y.isFinite else { return }
        viewport = V2(max(1, size.x), max(1, size.y))
        clampCenter()
    }

    public mutating func setZoom(_ value: Double) {
        guard value.isFinite else { return }
        zoom = min(4, max(1, value))
        clampCenter()
    }

    public mutating func pan(screenDelta: V2) {
        guard screenDelta.x.isFinite, screenDelta.y.isFinite else { return }
        center = center - screenDelta * (1 / scale)
        clampCenter()
    }

    public mutating func focus(_ point: V2, zoom: Double = 2) {
        guard point.x.isFinite, point.y.isFinite else { return }
        self.center = point
        setZoom(zoom)
    }

    private mutating func clampCenter() {
        func axis(_ c: Double, world: Double, screen: Double) -> Double {
            let half = min(world / 2, screen / (2 * scale))
            return min(world - half, max(half, c))
        }
        center = V2(axis(center.x, world: worldSize.x, screen: viewport.x),
                    axis(center.y, world: worldSize.y, screen: viewport.y))
    }
}

public enum BattleMapInput {
    public static let pointsPerTile = 20.0
    /// Reject outside taps; use the identical clamped point for ghost and actual deployment.
    public static func deploymentPoint(world: V2) -> V2? {
        let p = world * (1 / pointsPerTile)
        guard p.x.isFinite, p.y.isFinite, (0...40).contains(p.x), (20...40).contains(p.y) else { return nil }
        return V2(min(39.5, max(0.5, p.x)), min(39.5, max(20, p.y)))
    }

    public static func deploymentPoint(screen: V2, camera: MapCamera) -> V2? {
        deploymentPoint(world: camera.screenToWorld(screen))
    }
}
