/// Юниты: боевые коты игрока и враги (раки, псы, волки и прочие негодяи).
public enum UnitID: String, CaseIterable, Codable, Identifiable, Hashable {
    // Армия игрока
    case kitten
    case warrior
    case mouser
    case wizard
    case tiger
    // Враги
    case hamster
    case raccoon
    case banditCat
    case dog
    case wolf
    case alphaWolf

    public var id: String { rawValue }

    public var isPlayerUnit: Bool {
        switch self {
        case .kitten, .warrior, .mouser, .wizard, .tiger:
            return true
        default:
            return false
        }
    }

    public var emoji: String {
        switch self {
        case .kitten:    return "🐈"
        case .warrior:   return "🐱"
        case .mouser:    return "🐈‍⬛"
        case .wizard:    return "😺"
        case .tiger:     return "🐯"
        case .hamster:   return "🐹"
        case .raccoon:   return "🦝"
        case .banditCat: return "😼"
        case .dog:       return "🐕"
        case .wolf:      return "🐺"
        case .alphaWolf: return "🐺"
        }
    }

    public var ruName: String {
        switch self {
        case .kitten:    return "Котёнок"
        case .warrior:   return "Боевой кот"
        case .mouser:    return "Мышелов-стрелок"
        case .wizard:    return "Кот-чародей"
        case .tiger:     return "Тигр-танк"
        case .hamster:   return "Хомяк-грабитель"
        case .raccoon:   return "Бандит-рак"
        case .banditCat: return "Кот-бандит"
        case .dog:       return "Пёс-нахал"
        case .wolf:      return "Серый волк"
        case .alphaWolf: return "Альфа-волк"
        }
    }
}

/// Статистика юнита.
public struct UnitDef: Equatable {
    public let id: UnitID
    /// Здоровье без бонусов Мастерской усов.
    public let baseHP: Int
    /// Урон за удар.
    public let baseDamage: Int
    /// Дальность атаки в плитках.
    public let range: Double
    /// Скорость движения, плиток/сек.
    public let speed: Double
    /// Атак в секунду.
    public let attackSpeed: Double
    /// Радиус Splash-урона (0 — нет).
    public let splashRadius: Double
    /// Доля урона, летящая по Splash-окружности.
    public let splashFactor: Double
    /// Стоимость обучения.
    public let trainingCost: ResourceAmounts
    /// Время обучения, секунд (без скидки Мастерской).
    public let trainingTime: TimeInterval
    /// Минимальный уровень Дома котов для разблокировки.
    public let requiredHomeLevel: Int
    /// Минимальный уровень Академии котов для обучения.
    public let requiredAcademyLevel: Int
    /// Характер (описание в интерфейсе).
    public let flavor: String

    public init(
        id: UnitID,
        baseHP: Int,
        baseDamage: Int,
        range: Double,
        speed: Double,
        attackSpeed: Double,
        splashRadius: Double = 0,
        splashFactor: Double = 0,
        trainingCost: ResourceAmounts = .zero,
        trainingTime: TimeInterval = 0,
        requiredHomeLevel: Int = 0,
        requiredAcademyLevel: Int = 0,
        flavor: String = ""
    ) {
        self.id = id
        self.baseHP = baseHP
        self.baseDamage = baseDamage
        self.range = range
        self.speed = speed
        self.attackSpeed = attackSpeed
        self.splashRadius = splashRadius
        self.splashFactor = splashFactor
        self.trainingCost = trainingCost
        self.trainingTime = trainingTime
        self.requiredHomeLevel = requiredHomeLevel
        self.requiredAcademyLevel = requiredAcademyLevel
        self.flavor = flavor
    }
}

/// Статичная таблица юнитов.
public enum UnitTable {
    public static let defs: [UnitID: UnitDef] = {
        var d: [UnitID: UnitDef] = [:]

        // ── Армия игрока ────────────────────────────────────────────────
        d[.kitten] = UnitDef(
            id: .kitten,
            baseHP: 85, baseDamage: 10, range: 0.7, speed: 2.4, attackSpeed: 1.3,
            trainingCost: ResourceAmounts(cream: 25),
            trainingTime: 60,
            requiredHomeLevel: 1, requiredAcademyLevel: 1,
            flavor: "Быстрый и дерзкий. Лучше стайкой."
        )
        d[.warrior] = UnitDef(
            id: .warrior,
            baseHP: 240, baseDamage: 24, range: 0.7, speed: 1.9, attackSpeed: 1.0,
            trainingCost: ResourceAmounts(fish: 40, cream: 70),
            trainingTime: 150,
            requiredHomeLevel: 1, requiredAcademyLevel: 1,
            flavor: "Классика котобоевого искусства."
        )
        d[.mouser] = UnitDef(
            id: .mouser,
            baseHP: 105, baseDamage: 16, range: 5.5, speed: 2.6, attackSpeed: 1.5,
            trainingCost: ResourceAmounts(fish: 50, cream: 110),
            trainingTime: 180,
            requiredHomeLevel: 2, requiredAcademyLevel: 2,
            flavor: "Стреляет мышеловками с дальнего расстояния."
        )
        d[.wizard] = UnitDef(
            id: .wizard,
            baseHP: 140, baseDamage: 26, range: 6.5, speed: 1.7, attackSpeed: 0.8,
            splashRadius: 1.8, splashFactor: 0.5,
            trainingCost: ResourceAmounts(fish: 140, cream: 240),
            trainingTime: 300,
            requiredHomeLevel: 3, requiredAcademyLevel: 3,
            flavor: "Мурлычет заклинания. Бьёт по площади."
        )
        d[.tiger] = UnitDef(
            id: .tiger,
            baseHP: 750, baseDamage: 32, range: 0.7, speed: 1.3, attackSpeed: 0.9,
            trainingCost: ResourceAmounts(fish: 300, cream: 420),
            trainingTime: 420,
            requiredHomeLevel: 4, requiredAcademyLevel: 4,
            flavor: "Живая стена. Входит и мурлычет."
        )

        // ── Враги ───────────────────────────────────────────────────────
        d[.hamster] = UnitDef(
            id: .hamster,
            baseHP: 70, baseDamage: 8, range: 0.7, speed: 2.1, attackSpeed: 1.1,
            flavor: "Крошечный, но злой. Воришка."
        )
        d[.raccoon] = UnitDef(
            id: .raccoon,
            baseHP: 140, baseDamage: 15, range: 0.7, speed: 1.8, attackSpeed: 1.0,
            flavor: "Любит чужие миски и сундуки."
        )
        d[.banditCat] = UnitDef(
            id: .banditCat,
            baseHP: 170, baseDamage: 19, range: 0.7, speed: 2.0, attackSpeed: 1.1,
            flavor: "Кошка без дома. И со злым характером."
        )
        d[.dog] = UnitDef(
            id: .dog,
            baseHP: 300, baseDamage: 26, range: 0.7, speed: 1.7, attackSpeed: 0.9,
            flavor: "Нахальный пёс. Боится только тигров."
        )
        d[.wolf] = UnitDef(
            id: .wolf,
            baseHP: 380, baseDamage: 34, range: 0.7, speed: 2.3, attackSpeed: 1.0,
            flavor: "Быстрый и холодный."
        )
        d[.alphaWolf] = UnitDef(
            id: .alphaWolf,
            baseHP: 1200, baseDamage: 40, range: 1.0, speed: 1.5, attackSpeed: 0.8,
            flavor: "Глава стаи. Мурчание рядом с ним запрещено."
        )
        return d
    }()

    /// Статистика юнита. Таблица полная, поэтому force-unwrap безопасен.
    public static func def(_ id: UnitID) -> UnitDef {
        if let d = defs[id] {
            return d
        }
        fatalError("UnitTable: нет определения для \(id.rawValue)")
    }

    /// Все юниты игрока (в порядке разблокировки).
    public static var playerUnits: [UnitID] {
        return [.kitten, .warrior, .mouser, .wizard, .tiger]
    }
}
