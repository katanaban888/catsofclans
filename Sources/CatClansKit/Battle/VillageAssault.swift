import Foundation

/// App-only PvE configuration. Legacy EnemyGenerator and default battles are unchanged.
public struct VillageTarget: Equatable {
    public let type: BuildingType
    public let level: Int
    public let position: V2

    public init(_ type: BuildingType, level: Int = 1, at position: V2) {
        self.type = type
        self.level = level
        self.position = position
    }
}

public struct VillageAssault: Equatable {
    public let enemy: EnemyBase
    public let buildings: [VillageTarget]

    public static func make(difficulty: Int, seed: UInt64) -> VillageAssault {
        let d = min(5, max(1, difficulty))
        var enemy = EnemyGenerator.base(difficulty: d, seed: seed)
        enemy.name = ["Клубочный луг", "Тихие усы", "Рыбный переулок", "Мурлыкин посад", "Тигровый двор"][d - 1]
        enemy.coreName = "Дом котов"
        enemy.coreEmoji = "🏠"
        enemy.emoji = "🏡"
        enemy.defenders = [UnitSpawn(unit: d < 3 ? .kitten : .warrior, count: 2 + d)]
        if d >= 4 { enemy.defenders.append(UnitSpawn(unit: .wizard, count: 1)) }
        // Fixed layout: decoration and additional targets never draw from simulation RNG.
        let buildings: [VillageTarget] = [
            VillageTarget(.fishTrap, at: V2(10, 10)),
            VillageTarget(.creamBarrel, at: V2(30, 10)),
            VillageTarget(.toyShelf, at: V2(20, 8)),
            VillageTarget(.yarnMill, at: V2(9, 18)),
            VillageTarget(.bivouac, at: V2(31, 18)),
            VillageTarget(.wall, at: V2(13, 24)),
            VillageTarget(.wall, at: V2(27, 24))
        ]
        return VillageAssault(enemy: enemy, buildings: buildings)
    }
}
