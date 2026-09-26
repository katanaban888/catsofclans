/// Маленький 2D-вектор.
///
/// CoreGraphics (CGPoint) на Linux отсутствует, поэтому своё.
/// Все координаты боя — в «плитках», карта 40×40.
public struct V2: Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var length: Double {
        return (x * x + y * y).squareRoot()
    }

    public static func + (a: V2, b: V2) -> V2 {
        return V2(a.x + b.x, a.y + b.y)
    }

    public static func - (a: V2, b: V2) -> V2 {
        return V2(a.x - b.x, a.y - b.y)
    }

    public static func * (a: V2, s: Double) -> V2 {
        return V2(a.x * s, a.y * s)
    }

    public mutating func moveToward(_ target: V2, distance: Double) {
        let d = target - self
        let len = d.length
        if len <= distance || len == 0 {
            self = target
        } else {
            self = self + (d * (distance / len))
        }
    }
}

/// Расстояние между двумя точками.
public func v2Distance(_ a: V2, _ b: V2) -> Double {
    return (a - b).length
}
