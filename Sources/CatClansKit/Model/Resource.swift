/// Ресурсы игры.
///
/// 🐟 Рыба   — базовая валюта построек (рыбные ловушки).
/// 🥛 Сметана — базовая валюта улучшений и армии (сметанные бочонки).
/// 🧶 Пряжа  — редкая валюта оборонительных построек (полки игрушек).
/// 🐭 Мыши   — премиум-валюта, добывается только в рейдах.
public enum Resource: String, CaseIterable, Codable, Identifiable, Hashable {
    case fish
    case cream
    case yarn
    case mouse

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .fish:  return "🐟"
        case .cream: return "🥛"
        case .yarn:  return "🧶"
        case .mouse: return "🐭"
        }
    }

    public var ruName: String {
        switch self {
        case .fish:  return "Рыба"
        case .cream: return "Сметана"
        case .yarn:  return "Пряжа"
        case .mouse: return "Мыши"
        }
    }
}

/// Набор количеств ресурсов.
public struct ResourceAmounts: Codable, Equatable, Hashable {
    public var fish: Int
    public var cream: Int
    public var yarn: Int
    public var mouse: Int

    public init(fish: Int = 0, cream: Int = 0, yarn: Int = 0, mouse: Int = 0) {
        self.fish = fish
        self.cream = cream
        self.yarn = yarn
        self.mouse = mouse
    }

    public static let zero = ResourceAmounts()

    public subscript(resource: Resource) -> Int {
        get {
            switch resource {
            case .fish:  return fish
            case .cream: return cream
            case .yarn:  return yarn
            case .mouse: return mouse
            }
        }
        set {
            switch resource {
            case .fish:  fish = newValue
            case .cream: cream = newValue
            case .yarn:  yarn = newValue
            case .mouse: mouse = newValue
            }
        }
    }

    public static func + (a: ResourceAmounts, b: ResourceAmounts) -> ResourceAmounts {
        return ResourceAmounts(
            fish: a.fish + b.fish,
            cream: a.cream + b.cream,
            yarn: a.yarn + b.yarn,
            mouse: a.mouse + b.mouse
        )
    }

    public static func - (a: ResourceAmounts, b: ResourceAmounts) -> ResourceAmounts {
        return ResourceAmounts(
            fish: a.fish - b.fish,
            cream: a.cream - b.cream,
            yarn: a.yarn - b.yarn,
            mouse: a.mouse - b.mouse
        )
    }

    /// Умножить все компоненты на коэффициент (с округлением).
    public func scaled(_ k: Double) -> ResourceAmounts {
        return ResourceAmounts(
            fish: Int((Double(fish) * k).rounded()),
            cream: Int((Double(cream) * k).rounded()),
            yarn: Int((Double(yarn) * k).rounded()),
            mouse: Int((Double(mouse) * k).rounded())
        )
    }

    public func canAfford(_ cost: ResourceAmounts) -> Bool {
        return fish >= cost.fish
            && cream >= cost.cream
            && yarn >= cost.yarn
            && mouse >= cost.mouse
    }

    public mutating func add(_ other: ResourceAmounts) {
        self = self + other
    }

    public mutating func spend(_ cost: ResourceAmounts) {
        self = self - cost
    }

    /// Строка вида «🐟 220  🥛 120  🧶 20  🐭 2» (только ненулевые).
    public var display: String {
        var parts: [String] = []
        for r in Resource.allCases {
            let v = self[r]
            if v != 0 {
                parts.append("\(r.emoji) \(v)")
            }
        }
        if parts.isEmpty { return "—" }
        return parts.joined(separator: "  ")
    }
}
