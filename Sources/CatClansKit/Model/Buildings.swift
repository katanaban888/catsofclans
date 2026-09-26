import Foundation

/// Типы зданий деревни.
public enum BuildingType: String, CaseIterable, Codable, Identifiable, Hashable {
    case home
    case workshop
    case fishTrap
    case creamBarrel
    case toyShelf
    case academy
    case wall
    case cannon
    case sniper
    case trap
    case yarnMill
    case mouseExpedition
    case bivouac

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .home:        return "🏠"
        case .workshop:    return "🔧"
        case .fishTrap:    return "🎣"
        case .creamBarrel: return "🛢️"
        case .toyShelf:    return "🧸"
        case .academy:     return "🎓"
        case .wall:        return "🧱"
        case .cannon:      return "💣"
        case .sniper:      return "🎯"
        case .trap:        return "🪤"
        case .yarnMill: return "🧵"
        case .mouseExpedition: return "🗺️"
        case .bivouac: return "⛺"
        }
    }

    public var ruName: String {
        switch self {
        case .home:        return "Дом котов"
        case .workshop:    return "Мастерская усов"
        case .fishTrap:    return "Рыбная ловушка"
        case .creamBarrel: return "Сметанный бочонок"
        case .toyShelf:    return "Полка игрушек"
        case .academy:     return "Академия котов"
        case .wall:        return "Молочный забор"
        case .cannon:      return "Пушка мурлыки"
        case .sniper:      return "Снайперские усы"
        case .trap:        return "Котоловушка"
        case .yarnMill: return "Клубочная мастерская"
        case .mouseExpedition: return "Мышиная экспедиция"
        case .bivouac: return "Кошачий бивак"
        }
    }

    public var flavor: String {
        switch self {
        case .yarnMill: return "Наматывает пряжу: +3 в минуту за уровень. До 4 уровней; нужен Дом 2."
        case .mouseExpedition: return "Разведчики приносят 1 мышь в час за уровень. Одна экспедиция, до 3 уровней; нужен Дом 4."
        case .bivouac: return "Уютный лагерь даёт +2 места в армии за уровень. До 3 уровней; нужен Дом 2. Не заменяет Академию."
        case .home:        return "Сердце деревни. Его уровень открывает новые постройки и бойцов."
        case .workshop:    return "Усиливает здоровье и урон всей армии, ускоряет обучение."
        case .fishTrap:    return "Ловит рыб. Источник 🐟."
        case .creamBarrel: return "Варит сметану. Источник 🥛."
        case .toyShelf:    return "Хранит клубки. Источник 🧶."
        case .academy:     return "Тренирует боевых котов. Определяет размер армии."
        case .wall:        return "Плотный забор из бутылочек. Служит живой подушкой в обороне."
        case .cannon:      return "Стреляет консервными банками по врагам."
        case .sniper:      return "Один выстрел — и враг понимает, что мурлыкать пришло ему."
        case .trap:        return "Опускается на первого попавшегося врага и оглушает его."
        }
    }
}

/// Описание здания (статичные данные).
public struct BuildingDef: Equatable {
    public let type: BuildingType
    public let maxLevel: Int
    /// Минимальный уровень Дома котов для постройки. 0 — доступно всегда.
    public let requiredHomeLevel: Int
    /// Базовая стоимость постройки 1 уровня.
    public let baseBuildCost: ResourceAmounts
    /// Производство ресурсов в минуту на 1 уровне (линейно умножается на уровень).
    public let baseProductionPerMinute: [Resource: Double]
    /// Базовое HP, умножается на уровень (для дома/заборов/башен).
    public let baseHP: Int
    // Стрелковая башня (0 damage — башни нет).
    public let towerRange: Double
    public let towerDamage: Int
    public let towerAttackSpeed: Double
    // Ловушка.
    public let trapRadius: Double
    public let trapStun: TimeInterval

    public init(
        type: BuildingType,
        maxLevel: Int = 5,
        requiredHomeLevel: Int,
        baseBuildCost: ResourceAmounts,
        baseProductionPerMinute: [Resource: Double] = [:],
        baseHP: Int,
        towerRange: Double = 0,
        towerDamage: Int = 0,
        towerAttackSpeed: Double = 0,
        trapRadius: Double = 0,
        trapStun: TimeInterval = 0
    ) {
        self.type = type
        self.maxLevel = maxLevel
        self.requiredHomeLevel = requiredHomeLevel
        self.baseBuildCost = baseBuildCost
        self.baseProductionPerMinute = baseProductionPerMinute
        self.baseHP = baseHP
        self.towerRange = towerRange
        self.towerDamage = towerDamage
        self.towerAttackSpeed = towerAttackSpeed
        self.trapRadius = trapRadius
        self.trapStun = trapStun
    }

    public var isTower: Bool { towerDamage > 0 }

    // Удобен при печати: описание делегируется типу.
    public var emoji: String { type.emoji }
    public var ruName: String { type.ruName }
    public var flavor: String { type.flavor }
}

/// Статичная таблица зданий и расчёты от уровней.
public enum BuildingTable {
    public static let defs: [BuildingType: BuildingDef] = {
        var d: [BuildingType: BuildingDef] = [:]

        d[.home] = BuildingDef(
            type: .home, maxLevel: 5, requiredHomeLevel: 0,
            baseBuildCost: .zero, baseHP: 1000
        )
        d[.workshop] = BuildingDef(
            type: .workshop, requiredHomeLevel: 3,
            baseBuildCost: ResourceAmounts(fish: 250, cream: 80), baseHP: 150
        )
        d[.fishTrap] = BuildingDef(
            type: .fishTrap, requiredHomeLevel: 1,
            baseBuildCost: ResourceAmounts(fish: 100),
            baseProductionPerMinute: [.fish: 10], baseHP: 150
        )
        d[.creamBarrel] = BuildingDef(
            type: .creamBarrel, requiredHomeLevel: 1,
            baseBuildCost: ResourceAmounts(fish: 120),
            baseProductionPerMinute: [.cream: 6], baseHP: 150
        )
        d[.toyShelf] = BuildingDef(
            type: .toyShelf, requiredHomeLevel: 2,
            baseBuildCost: ResourceAmounts(fish: 150, yarn: 25),
            baseProductionPerMinute: [.yarn: 4], baseHP: 150
        )
        d[.academy] = BuildingDef(
            type: .academy, requiredHomeLevel: 1,
            baseBuildCost: ResourceAmounts(fish: 180, cream: 60), baseHP: 200
        )
        d[.wall] = BuildingDef(
            type: .wall, requiredHomeLevel: 1,
            baseBuildCost: ResourceAmounts(fish: 60), baseHP: 400
        )
        d[.cannon] = BuildingDef(
            type: .cannon, requiredHomeLevel: 3,
            baseBuildCost: ResourceAmounts(fish: 350, yarn: 40), baseHP: 250,
            towerRange: 7.5, towerDamage: 26, towerAttackSpeed: 0.8
        )
        d[.sniper] = BuildingDef(
            type: .sniper, requiredHomeLevel: 4,
            baseBuildCost: ResourceAmounts(fish: 500, yarn: 70), baseHP: 200,
            towerRange: 12.0, towerDamage: 70, towerAttackSpeed: 0.35
        )
        d[.trap] = BuildingDef(
            type: .trap, requiredHomeLevel: 5,
            baseBuildCost: ResourceAmounts(fish: 700, yarn: 120), baseHP: 100,
            trapRadius: 3.5, trapStun: 2.5
        )
        d[.yarnMill] = BuildingDef(
            type: .yarnMill, maxLevel: 4, requiredHomeLevel: 2,
            baseBuildCost: ResourceAmounts(fish: 280, cream: 100, yarn: 30),
            baseProductionPerMinute: [.yarn: 3], baseHP: 180
        )
        d[.mouseExpedition] = BuildingDef(
            type: .mouseExpedition, maxLevel: 3, requiredHomeLevel: 4,
            baseBuildCost: ResourceAmounts(fish: 1000, cream: 600, yarn: 200),
            baseProductionPerMinute: [.mouse: 1.0 / 60.0], baseHP: 180
        )
        d[.bivouac] = BuildingDef(
            type: .bivouac, maxLevel: 3, requiredHomeLevel: 2,
            baseBuildCost: ResourceAmounts(fish: 320, cream: 150, yarn: 50), baseHP: 220
        )
        return d
    }()

    public static func def(_ type: BuildingType) -> BuildingDef {
        if let d = defs[type] {
            return d
        }
        fatalError("BuildingTable: нет определения для \(type.rawValue)")
    }

    public static func armyCapacityBonus(_ type: BuildingType, level: Int) -> Int {
        type == .bivouac ? 2 * max(0, level) : 0
    }

    /// Только экспедиция ограничена одной постройкой: мыши остаются боевой наградой.
    public static func buildLimit(_ type: BuildingType) -> Int? {
        type == .mouseExpedition ? 1 : nil
    }

    /// Стоимость постройки 1 уровня.
    public static func buildCost(_ type: BuildingType) -> ResourceAmounts {
        return def(type).baseBuildCost
    }

    /// Стоимость улучшения до уровня `level` (level > 1).
    /// Дом котов растёт квадратично, остальные — линейно от базовой цены.
    public static func upgradeCost(_ type: BuildingType, toLevel level: Int) -> ResourceAmounts {
        let base = def(type).baseBuildCost
        if type == .home {
            let k = level - 1
            return ResourceAmounts(
                fish: 250 * k * k,
                cream: 150 * k * k,
                yarn: 50 * k
            )
        }
        let k = Double(level - 1) * 1.7
        return base.scaled(k)
    }

    /// Производство в минуту на данном уровне.
    public static func production(_ type: BuildingType, level: Int) -> [Resource: Double] {
        let base = def(type).baseProductionPerMinute
        var out: [Resource: Double] = [:]
        for (r, v) in base {
            out[r] = v * Double(level)
        }
        return out
    }

    /// Максимальное HP здания на данном уровне.
    public static func maxHP(_ type: BuildingType, level: Int) -> Int {
        return def(type).baseHP * level
    }

    /// Урон башни на данном уровне.
    public static func towerDamage(_ type: BuildingType, level: Int) -> Int {
        return def(type).towerDamage * level
    }
}
