import Foundation

/// Команды в бою.
public enum Team: Int, Codable, Equatable, Hashable {
    case player = 0
    case enemy = 1

    public var other: Team {
        return self == .player ? .enemy : .player
    }
}

/// Режим боя.
public enum BattleMode: Equatable {
    /// Мы атакуем вражескую базу.
    case attack
    /// Нас атакуют — обороняемся башнями.
    case defense
}

/// Боевые характеристики юнита на момент боя.
public struct UnitStats: Codable, Equatable {
    public var id: UnitID
    public var maxHP: Int
    public var damage: Int
    public var range: Double
    public var speed: Double
    public var attackSpeed: Double
    public var splashRadius: Double
    public var splashFactor: Double

    /// Создать из таблицы с множителями (бонусы Мастерской усов).
    public init(id: UnitID, hpScale: Double = 1, dmgScale: Double = 1) {
        let def = UnitTable.def(id)
        self.id = id
        self.maxHP = max(1, Int((Double(def.baseHP) * hpScale).rounded()))
        self.damage = max(1, Int((Double(def.baseDamage) * dmgScale).rounded()))
        self.range = def.range
        self.speed = def.speed
        self.attackSpeed = def.attackSpeed
        self.splashRadius = def.splashRadius
        self.splashFactor = def.splashFactor
    }
}

/// Юнит в бою (мутируемый объект — симуляция обновляет его на месте).
public final class BattleUnit: Identifiable {
    public let id: Int
    public let team: Team
    public let stats: UnitStats
    public var pos: V2
    public var hp: Int
    /// До какого игрового времени оглушён (ловушки).
    public var stunUntil: TimeInterval = 0
    /// Остаток до следующего выстрела.
    public var cooldown: TimeInterval = 0
    /// Уже попал ли в ловушку (однократный эффект).
    public var isTrapped: Bool = false

    public init(id: Int, team: Team, stats: UnitStats, pos: V2) {
        self.id = id
        self.team = team
        self.stats = stats
        self.pos = pos
        self.hp = stats.maxHP
    }

    public var isAlive: Bool { hp > 0 }
}

/// Строение в бою: ядро базы, башня, забор, ловушка.
public final class BattleStructure: Identifiable {
    public let id: Int
    public let team: Team
    public let type: BuildingType
    public let name: String
    public let emoji: String
    public let pos: V2
    public var hp: Int
    public let maxHP: Int
    public let isCore: Bool
    public let isTower: Bool
    public let isTrap: Bool
    public let range: Double
    public let damage: Int
    public let attackSpeed: Double
    public let trapRadius: Double
    public let trapStun: TimeInterval
    public var cooldown: TimeInterval = 0

    public init(
        id: Int,
        team: Team,
        type: BuildingType,
        name: String,
        emoji: String,
        pos: V2,
        hp: Int,
        isCore: Bool,
        range: Double,
        damage: Int,
        attackSpeed: Double,
        trapRadius: Double,
        trapStun: TimeInterval
    ) {
        self.id = id
        self.team = team
        self.type = type
        self.name = name
        self.emoji = emoji
        self.pos = pos
        self.hp = hp
        self.maxHP = hp
        self.isCore = isCore
        self.isTower = damage > 0
        self.isTrap = trapRadius > 0
        self.range = range
        self.damage = damage
        self.attackSpeed = attackSpeed
        self.trapRadius = trapRadius
        self.trapStun = trapStun
    }

    public var isAlive: Bool { hp > 0 }
}

public enum BattleEventKind: Equatable {
    case start
    case destroyed
    case killed
    case stun
    case victory
    case defeat
}

/// Событие боя (для ленты событий и демо).
public struct BattleEvent: Identifiable, Equatable {
    public let id: Int
    public var t: TimeInterval
    public var kind: BattleEventKind
    public var text: String
    public var pos: V2

    public init(id: Int, t: TimeInterval, kind: BattleEventKind, text: String, pos: V2) {
        self.id = id
        self.t = t
        self.kind = kind
        self.text = text
        self.pos = pos
    }
}

/// Итог боя.
public struct BattleResult: Codable, Equatable {
    public var victory: Bool
    public var duration: TimeInterval
    public var loot: ResourceAmounts
    public var xp: Int
    public var destroyedStructures: Int
    public var totalStructures: Int
    /// Доля (0...1) урона, нанесённая ядру (дома).
    public var coreDamageFrac: Double

    public init(
        victory: Bool,
        duration: TimeInterval,
        loot: ResourceAmounts,
        xp: Int,
        destroyedStructures: Int,
        totalStructures: Int,
        coreDamageFrac: Double
    ) {
        self.victory = victory
        self.duration = duration
        self.loot = loot
        self.xp = xp
        self.destroyedStructures = destroyedStructures
        self.totalStructures = totalStructures
        self.coreDamageFrac = coreDamageFrac
    }
}

/// Башня, которую ставит генератор на вражескую базу.
public struct TowerSpawn: Equatable, Hashable {
    public var type: BuildingType
    public var level: Int

    public init(type: BuildingType, level: Int) {
        self.type = type
        self.level = level
    }
}

/// Группа юнитов, которую ставит генератор.
public struct UnitSpawn: Equatable, Hashable {
    public var unit: UnitID
    public var count: Int

    public init(unit: UnitID, count: Int) {
        self.unit = unit
        self.count = count
    }
}

/// Генерируемая вражеская база (для атак) или группа рейдеров (для рейдов по нам).
public struct EnemyBase: Equatable {
    public var difficulty: Int
    public var name: String
    public var emoji: String
    public var coreName: String
    public var coreEmoji: String
    public var coreHP: Int
    public var towers: [TowerSpawn]
    public var defenders: [UnitSpawn]
    public var loot: ResourceAmounts
    public var xp: Int

    public init(
        difficulty: Int,
        name: String,
        emoji: String,
        coreName: String,
        coreEmoji: String,
        coreHP: Int,
        towers: [TowerSpawn],
        defenders: [UnitSpawn],
        loot: ResourceAmounts,
        xp: Int
    ) {
        self.difficulty = difficulty
        self.name = name
        self.emoji = emoji
        self.coreName = coreName
        self.coreEmoji = coreEmoji
        self.coreHP = coreHP
        self.towers = towers
        self.defenders = defenders
        self.loot = loot
        self.xp = xp
    }
}
