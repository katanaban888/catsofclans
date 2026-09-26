import Foundation

/// Генерация вражеских баз и рейдов.
///
/// Всё детерминировано: один (difficulty, seed) — одна и та же база.
public enum EnemyGenerator {

    /// Базы, которые можно атаковать (сложность 1...5).
    public static func base(difficulty: Int, seed: UInt64) -> EnemyBase {
        var rng = SeededRNG(seed: seed &+ UInt64(max(1, difficulty)) &* 7919)
        switch difficulty {
        case 1:  return makeHamsterBushes(&rng)
        case 2:  return makeRaccoonDen(&rng)
        case 3:  return makeCatGang(&rng)
        case 4:  return makeDogPack(&rng)
        default: return makeWolfDen(&rng)
        }
    }

    /// Рейд на нашу деревню. Сила — от уровня игрока.
    /// Возвращает «базу» без ядра и башен: только группа рейдеров.
    public static func raid(playerLevel: Int, seed: UInt64) -> EnemyBase {
        var rng = SeededRNG(seed: seed &+ UInt64(max(1, playerLevel)) &* 104729)
        let level = max(1, min(10, playerLevel))

        var pool: [UnitID] = [.hamster, .raccoon]
        if level >= 3 { pool.append(.banditCat) }
        if level >= 5 { pool.append(.dog) }
        if level >= 8 { pool.append(.wolf) }

        // 30 секунд штурма: на низких уровнях рейд слабый (дом выдержит),
        // на высоких — серьёзная угроза без башен.
        let count = 1 + (level + 1) / 2
        var defenders: [UnitSpawn] = []
        for _ in 0..<count {
            let u = rng.pick(pool)
            if let idx = defenders.firstIndex(where: { $0.unit == u }) {
                defenders[idx].count += 1
            } else {
                defenders.append(UnitSpawn(unit: u, count: 1))
            }
        }
        // На высоких уровнях иногда приходит альфа-волк.
        if level >= 10 && rng.chance(0.3) {
            defenders.append(UnitSpawn(unit: .alphaWolf, count: 1))
        }

        let name = rng.pick(raidNames(level: level))
        return EnemyBase(
            difficulty: level,
            name: name,
            emoji: "🐾",
            coreName: "Ваш дом",
            coreEmoji: "🏠",
            coreHP: 0,
            towers: [],
            defenders: defenders,
            loot: .zero,
            xp: 10 + 4 * level
        )
    }

    // MARK: - Базы

    private static func makeHamsterBushes(_ rng: inout SeededRNG) -> EnemyBase {
        return EnemyBase(
            difficulty: 1,
            name: "Хомячьи кусты",
            emoji: "🐹",
            coreName: "Большая норка",
            coreEmoji: "🕳️",
            coreHP: Int((400 * rng.double(0.9, 1.1)).rounded()),
            towers: [],
            defenders: [UnitSpawn(unit: .hamster, count: 3)],
            loot: ResourceAmounts(fish: 220, cream: 120, yarn: 20, mouse: 2),
            xp: 25
        )
    }

    private static func makeRaccoonDen(_ rng: inout SeededRNG) -> EnemyBase {
        let raccoons = rng.int(4, 5)
        return EnemyBase(
            difficulty: 2,
            name: "Бандитская нора",
            emoji: "🦝",
            coreName: "Дупло-штаб",
            coreEmoji: "🌳",
            coreHP: Int((750 * rng.double(0.9, 1.1)).rounded()),
            towers: [],
            defenders: [UnitSpawn(unit: .raccoon, count: raccoons)],
            loot: ResourceAmounts(fish: 450, cream: 250, yarn: 40, mouse: 3),
            xp: 40
        )
    }

    private static func makeCatGang(_ rng: inout SeededRNG) -> EnemyBase {
        return EnemyBase(
            difficulty: 3,
            name: "Кошачья банда",
            emoji: "🐈‍⬛",
            coreName: "Гараж банды",
            coreEmoji: "🏚️",
            coreHP: Int((1250 * rng.double(0.9, 1.1)).rounded()),
            towers: [TowerSpawn(type: .cannon, level: 1)],
            defenders: [
                UnitSpawn(unit: .banditCat, count: rng.int(3, 5)),
                UnitSpawn(unit: .raccoon, count: 2),
            ],
            loot: ResourceAmounts(fish: 800, cream: 500, yarn: 120, mouse: 5),
            xp: 60
        )
    }

    private static func makeDogPack(_ rng: inout SeededRNG) -> EnemyBase {
        return EnemyBase(
            difficulty: 4,
            name: "Собачья пасть",
            emoji: "🐕",
            coreName: "Костяная башня",
            coreEmoji: "🦴",
            coreHP: Int((1400 * rng.double(0.9, 1.1)).rounded()),
            towers: [
                TowerSpawn(type: .cannon, level: 2),
                TowerSpawn(type: .sniper, level: 1),
            ],
            defenders: [
                UnitSpawn(unit: .dog, count: rng.int(2, 3)),
                UnitSpawn(unit: .wolf, count: 1),
            ],
            loot: ResourceAmounts(fish: 1400, cream: 900, yarn: 250, mouse: 8),
            xp: 85
        )
    }

    private static func makeWolfDen(_ rng: inout SeededRNG) -> EnemyBase {
        return EnemyBase(
            difficulty: 5,
            name: "Волчий причал",
            emoji: "🐺",
            coreName: "Застава Вальдара",
            coreEmoji: "🏔️",
            coreHP: Int((2200 * rng.double(0.9, 1.1)).rounded()),
            towers: [
                TowerSpawn(type: .cannon, level: 2),
                TowerSpawn(type: .sniper, level: 2),
            ],
            defenders: [
                UnitSpawn(unit: .wolf, count: 2),
                UnitSpawn(unit: .dog, count: 1),
                UnitSpawn(unit: .alphaWolf, count: 1),
              ],
            loot: ResourceAmounts(fish: 2400, cream: 1600, yarn: 500, mouse: 15),
            xp: 120
        )
    }

    // MARK: - Рейды

    private static func raidNames(level: Int) -> [String] {
        switch level {
        case 1:  return ["Хомячья шайка", "Воробьиный бунт", "Голодные хомяки"]
        case 2, 3: return ["Банда «Белые лапы»", "Рейд раков", "Компания «Мусорный ведро»"]
        case 4, 5: return ["Группировка «Чёрный нос»", "Банда «Чёрные лапы»", "Соседские коты"]
        case 6, 7: return ["Собачья банда «Лаяч»", "Псы с соседнего двора", "Гончая шайка"]
        default:   return ["Волчья стая", "Дети Вальдара", "Ледяной дозор"]
        }
    }
}
