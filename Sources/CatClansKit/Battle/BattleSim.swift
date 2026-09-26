import Foundation

/// Расстановка здания при генерации оборонительных позиций.
public struct BuildingPlacement: Equatable, Hashable {
    public var type: BuildingType
    public var level: Int

    public init(type: BuildingType, level: Int) {
        self.type = type
        self.level = level
    }
}

/// Детерминированная симуляция боя.
///
/// Карта 40×40 плиток. Такт 0.1 игровой секунды.
/// Атака: армия игрока заходит с нижнего края, база врага в центре сверху.
/// Оборона: дом игрока в центре, башни вокруг, рейдеры лезут с верхнего края.
public final class BattleSim {
    public static let mapSize: Double = 40
    /// Лимит времени атаки (3 минуты, как в клановых штурмах).
    public static let attackTimeLimit: TimeInterval = 180
    /// Лимит времени рейда по нам (30 секунд штурма, потом грабители отступают).
    public static let defenseTimeLimit: TimeInterval = 30
    public static let structureRadius: Double = 1.3
    public static let unitRadius: Double = 0.5

    public let dt: TimeInterval = 0.1

    public private(set) var units: [BattleUnit] = []
    public private(set) var structures: [BattleStructure] = []
    public private(set) var events: [BattleEvent] = []
    public private(set) var time: TimeInterval = 0
    public private(set) var finished: Bool = false
    public private(set) var result: BattleResult?

    public let mode: BattleMode
    public let enemyName: String
    public let enemyEmoji: String
    /// Лимит времени для конкретного боя.
    public let timeLimit: TimeInterval

    private let enemyLoot: ResourceAmounts
    private let enemyXP: Int
    private let totalEnemyStructures: Int
    private let totalEnemyValue: Double
    private var destroyedValue: Double = 0
    private var destroyedEnemyStructures = 0
    private var nextUnitID = 1
    private var nextStructureID = 1
    private var nextEventID = 1

    // MARK: - Создание

    /// Универсальная инициализация.
    public init(
        playerUnits: [UnitStats],
        playerStructures: [BuildingPlacement],
        enemy: EnemyBase,
        mode: BattleMode,
        playerCoreHP: Int? = nil,
        seed: UInt64
    ) {
        self.mode = mode
        self.enemyName = enemy.name
        self.enemyEmoji = enemy.emoji
        self.timeLimit = mode == .attack ? Self.attackTimeLimit : Self.defenseTimeLimit
        self.enemyLoot = enemy.loot
        self.enemyXP = enemy.xp

        var rng = SeededRNG(seed: seed)

        if mode == .attack {
            // Ядро врага чуть выше центра, армия игрока — снизу.
            let corePos = V2(20, 17)
            addStructure(
                type: .home, level: 1, pos: corePos, team: .enemy,
                name: enemy.coreName, emoji: enemy.coreEmoji, isCore: true,
                hpOverride: max(1, enemy.coreHP)
            )
            for (i, t) in enemy.towers.enumerated() {
                let towerCount = max(1, enemy.towers.count)
                let baseAngle = 2 * Double.pi * Double(i) / Double(towerCount)
                let angle = baseAngle + rng.double(-0.5, 0.5)
                let radius = rng.double(4.0, 6.5)
                let pos = V2(corePos.x + Foundation.cos(angle) * radius,
                             corePos.y + Foundation.sin(angle) * radius)
                let def = BuildingTable.def(t.type)
                addStructure(
                    type: t.type, level: t.level, pos: pos, team: .enemy,
                    name: def.ruName, emoji: def.emoji, isCore: false, hpOverride: nil
                )
            }
            for spawn in enemy.defenders {
                let anchor: V2
                let towerStructs = structures.filter { $0.isTower && $0.team == .enemy }
                if !towerStructs.isEmpty && rng.chance(0.6) {
                    let t = rng.pick(towerStructs)
                    anchor = t.pos + V2(rng.double(-1.5, 1.5), rng.double(-1.5, 1.5))
                } else {
                    let a = rng.double(0, 2 * Double.pi)
                    let r = rng.double(2.0, 4.5)
                    anchor = corePos + V2(Foundation.cos(a) * r, Foundation.sin(a) * r)
                }
                for _ in 0..<spawn.count {
                    let pos = anchor + V2(rng.double(-0.8, 0.8), rng.double(-0.8, 0.8))
                    addUnit(UnitStats(id: spawn.unit), team: .enemy, pos: pos)
                }
            }
            let n = playerUnits.count
            for (i, stats) in playerUnits.enumerated() {
                let x: Double
                if n <= 1 {
                    x = 20
                } else {
                    x = 8 + (32 - 8) * Double(i) / Double(n - 1)
                }
                addUnit(stats, team: .player, pos: V2(x, 38.5))
            }
        } else {
            // Оборона: дом в центре, башни и ловушки вокруг, рейдеры сверху.
            let center = V2(20, 20)
            let towerTypes: Set<BuildingType> = [.cannon, .sniper]
            let towerCount = playerStructures.filter { towerTypes.contains($0.type) }.count
            var towerIndex = 0
            for p in playerStructures {
                let def = BuildingTable.def(p.type)
                if p.type == .home {
                    let hp = playerCoreHP ?? BuildingTable.maxHP(.home, level: p.level)
                    addStructure(
                        type: .home, level: p.level, pos: center, team: .player,
                        name: def.ruName, emoji: def.emoji, isCore: true,
                        hpOverride: max(1, hp)
                    )
                } else {
                    let angle: Double
                    let radius: Double
                    if towerTypes.contains(p.type) {
                        // Башни встают на кольцо с равным шагом —
                        // между ними не остаётся «мёртвых зон».
                        let n = max(1, towerCount)
                        angle = (2 * Double.pi * Double(towerIndex) / Double(n)) + rng.double(-0.35, 0.35)
                        towerIndex += 1
                        radius = p.type == .cannon ? rng.double(4.0, 5.5) : rng.double(5.0, 6.5)
                    } else if p.type == .trap {
                        angle = rng.double(0, 2 * Double.pi)
                        radius = rng.double(2.5, 4.0)
                    } else {
                        angle = rng.double(0, 2 * Double.pi)
                        radius = rng.double(3.0, 5.0)
                    }
                    let pos = center + V2(Foundation.cos(angle) * radius, Foundation.sin(angle) * radius)
                    addStructure(
                        type: p.type, level: p.level, pos: pos, team: .player,
                        name: def.ruName, emoji: def.emoji, isCore: false, hpOverride: nil
                    )
                }
            }
            let totalRaiders = enemy.defenders.reduce(0) { $0 + $1.count }
            var idx = 0
            for spawn in enemy.defenders {
                for _ in 0..<spawn.count {
                    let x: Double
                    if totalRaiders <= 1 {
                        x = 20
                    } else {
                        x = 8 + (32 - 8) * Double(idx) / Double(totalRaiders - 1)
                    }
                    addUnit(UnitStats(id: spawn.unit), team: .enemy, pos: V2(x, 1.5))
                    idx += 1
                }
            }
        }

        let enemyStructs = structures.filter { $0.team == .enemy }
        totalEnemyStructures = enemyStructs.count
        let value = enemyStructs.reduce(0.0) { $0 + Double($1.maxHP) }
        totalEnemyValue = value > 0 ? value : 1

        let startText: String
        if mode == .attack {
            startText = "⚔️ Атака на \(enemy.emoji) \(enemy.name)!"
        } else {
            startText = "🚨 \(enemy.name) штурмуют вашу деревню!"
        }
        addEvent(.start, startText, V2(20, 20))
    }

    /// Бой из состояния деревни.
    /// В атаке нужна непустая армия, поэтому инициализация failable.
    public convenience init?(
        state: GameState,
        enemy: EnemyBase,
        mode: BattleMode,
        seed: UInt64
    ) {
        switch mode {
        case .attack:
            guard state.armySize > 0 else { return nil }
            self.init(
                playerUnits: state.armyStats,
                playerStructures: [],
                enemy: enemy,
                mode: mode,
                playerCoreHP: nil,
                seed: seed
            )
        case .defense:
            var placements: [BuildingPlacement] = []
            for b in state.buildings {
                switch b.type {
                case .home, .wall, .cannon, .sniper, .trap:
                    placements.append(BuildingPlacement(type: b.type, level: b.level))
                default:
                    break
                }
            }
            self.init(
                playerUnits: [],
                playerStructures: placements,
                enemy: enemy,
                mode: mode,
                playerCoreHP: Int(state.homeHP),
                seed: seed
            )
        }
    }

    // MARK: - Фабрики

    private func addUnit(_ stats: UnitStats, team: Team, pos: V2) {
        units.append(BattleUnit(id: nextUnitID, team: team, stats: stats, pos: pos))
        nextUnitID += 1
    }

    private func addStructure(
        type: BuildingType,
        level: Int,
        pos: V2,
        team: Team,
        name: String,
        emoji: String,
        isCore: Bool,
        hpOverride: Int?
    ) -> BattleStructure {
        let def = BuildingTable.def(type)
        let hp = hpOverride ?? BuildingTable.maxHP(type, level: level)
        let s = BattleStructure(
            id: nextStructureID,
            team: team,
            type: type,
            name: name,
            emoji: emoji,
            pos: pos,
            hp: max(1, hp),
            isCore: isCore,
            range: def.towerRange,
            damage: BuildingTable.towerDamage(type, level: level),
            attackSpeed: def.towerAttackSpeed,
            trapRadius: def.trapRadius,
            trapStun: def.trapStun
        )
        structures.append(s)
        nextStructureID += 1
        return s
    }

    private func addEvent(_ kind: BattleEventKind, _ text: String, _ pos: V2) {
        events.append(BattleEvent(id: nextEventID, t: time, kind: kind, text: text, pos: pos))
        nextEventID += 1
    }

    // MARK: - Симуляция

    /// Один такт (0.1 игровой секунды).
    public func step() {
        guard !finished else { return }
        time += dt
        fireTowers()
        moveAndAttackUnits()
        triggerTraps()
        units.removeAll { !$0.isAlive }
        checkEnd()
    }

    /// Прогнать бой до конца (для демо и тестов).
    @discardableResult
    public func runToEnd() -> BattleResult? {
        while !finished && time <= timeLimit + 5 {
            step()
        }
        return result
    }

    /// Сдаться — только в атаке. Бой заканчивается поражением.
    public func surrender() {
        guard !finished, mode == .attack else { return }
        finish(victory: false)
    }

    private func fireTowers() {
        for s in structures where s.isTower && s.isAlive {
            s.cooldown -= dt
            guard s.cooldown <= 0 else { continue }
            var target: BattleUnit?
            var bestDist = Double.greatestFiniteMagnitude
            for u in units where u.isAlive && u.team != s.team {
                let d = v2Distance(u.pos, s.pos)
                if d <= s.range && d < bestDist {
                    bestDist = d
                    target = u
                }
            }
            guard let t = target else { continue }
            s.cooldown = 1.0 / max(0.1, s.attackSpeed)
            damageUnit(t, amount: s.damage)
        }
    }

    private func moveAndAttackUnits() {
        for u in units where u.isAlive {
            if time < u.stunUntil { continue }
            u.cooldown -= dt

            var bestDist = Double.greatestFiniteMagnitude
            var bestStruct: BattleStructure?
            var bestUnit: BattleUnit?

            for s in structures where s.isAlive && s.team != u.team {
                let d = v2Distance(u.pos, s.pos) - Self.structureRadius
                if d < bestDist {
                    bestDist = d
                    bestStruct = s
                    bestUnit = nil
                }
            }
            for v in units where v.isAlive && v.team != u.team {
                let d = v2Distance(u.pos, v.pos) - Self.unitRadius
                if d < bestDist {
                    bestDist = d
                    bestUnit = v
                    bestStruct = nil
                }
            }
            guard bestStruct != nil || bestUnit != nil else { return }

            let targetPos: V2
            if let s = bestStruct {
                targetPos = s.pos
            } else {
                targetPos = bestUnit!.pos
            }

            if bestDist <= u.stats.range {
                if u.cooldown <= 0 {
                    u.cooldown = 1.0 / max(0.1, u.stats.attackSpeed)
                    if let s = bestStruct {
                        damageStructure(s, amount: u.stats.damage)
                    } else if let v = bestUnit {
                        damageUnit(v, amount: u.stats.damage)
                    }
                    applySplash(from: u, targetPos: targetPos, primaryUnit: bestUnit, primaryStruct: bestStruct)
                }
            } else {
                u.pos.moveToward(targetPos, distance: u.stats.speed * dt)
            }
        }
    }

    private func applySplash(
        from u: BattleUnit,
        targetPos: V2,
        primaryUnit: BattleUnit?,
        primaryStruct: BattleStructure?
    ) {
        guard u.stats.splashRadius > 0 else { return }
        let splashDamage = max(1, Int((Double(u.stats.damage) * u.stats.splashFactor).rounded()))
        for v in units where v.isAlive && v.team != u.team && v !== primaryUnit {
            if v2Distance(v.pos, targetPos) <= u.stats.splashRadius {
                damageUnit(v, amount: splashDamage)
            }
        }
        for s in structures where s.isAlive && s.team != u.team && s !== primaryStruct {
            if v2Distance(s.pos, targetPos) <= u.stats.splashRadius {
                damageStructure(s, amount: splashDamage)
            }
        }
    }

    private func triggerTraps() {
        for s in structures where s.isTrap && s.isAlive {
            for u in units where u.isAlive && !u.isTrapped && u.team != s.team {
                if v2Distance(u.pos, s.pos) <= s.trapRadius {
                    u.isTrapped = true
                    u.stunUntil = time + s.trapStun
                    addEvent(.stun, "🪤 \(u.stats.id.emoji) \(u.stats.id.ruName) попал в котоловушку!", s.pos)
                }
            }
        }
    }

    private func damageUnit(_ v: BattleUnit, amount: Int) {
        guard v.isAlive, amount > 0 else { return }
        v.hp -= amount
        if v.hp <= 0 {
            v.hp = 0
            addEvent(.killed, "\(v.stats.id.emoji) \(v.stats.id.ruName) выбывает из боя!", v.pos)
        }
    }

    private func damageStructure(_ s: BattleStructure, amount: Int) {
        guard s.isAlive, amount > 0 else { return }
        s.hp -= amount
        if s.hp <= 0 {
            s.hp = 0
            if s.team == .enemy {
                destroyedValue += Double(s.maxHP)
                destroyedEnemyStructures += 1
                addEvent(.destroyed, "💥 Разрушено: \(s.emoji) \(s.name)", s.pos)
            } else {
                addEvent(.destroyed, "💔 Разрушено: \(s.emoji) \(s.name)", s.pos)
            }
        }
    }

    private func checkEnd() {
        let enemyStructAlive = structures.contains { $0.team == .enemy && $0.isAlive }
        let enemyUnitAlive = units.contains { $0.team == .enemy && $0.isAlive }
        let playerUnitAlive = units.contains { $0.team == .player && $0.isAlive }
        let playerStructAlive = structures.contains { $0.team == .player && $0.isAlive }

        if mode == .attack {
            if !enemyStructAlive {
                finish(victory: true)
                return
            }
            if !playerUnitAlive {
                finish(victory: false)
                return
            }
            if time >= timeLimit {
                // Время вышло: победа, если ядро базы разрушено.
                let coreAlive = structures.contains { $0.team == .enemy && $0.isCore && $0.isAlive }
                finish(victory: !coreAlive)
            }
        } else {
            if !enemyUnitAlive {
                finish(victory: true)
                return
            }
            if !playerStructAlive {
                finish(victory: false)
                return
            }
            if time >= timeLimit {
                // Время штурма вышло — грабители отступают.
                finish(victory: false)
            }
        }
    }

    private func finish(victory: Bool) {
        guard !finished else { return }
        finished = true

        var loot = ResourceAmounts.zero
        var xp = 0

        if mode == .attack {
            let frac = min(1.0, destroyedValue / totalEnemyValue)
            if victory {
                loot = enemyLoot
                xp = enemyXP
            } else {
                // Поражение: уносим 40% от уничтоженной доли.
                loot = enemyLoot.scaled(frac * 0.4)
                xp = Int((Double(enemyXP) * 0.5).rounded())
            }
        } else {
            if victory {
                loot = ResourceAmounts(mouse: 1 + enemyXP / 20)
                xp = enemyXP
            } else {
                xp = max(1, enemyXP / 3)
            }
        }

        let coreTeam: Team = mode == .attack ? .enemy : .player
        let core = structures.first { $0.team == coreTeam && $0.isCore }
        let coreDamageFrac: Double
        if let c = core {
            coreDamageFrac = c.maxHP > 0 ? Double(c.maxHP - c.hp) / Double(c.maxHP) : 0
        } else {
            coreDamageFrac = 1
        }

        result = BattleResult(
            victory: victory,
            duration: time,
            loot: loot,
            xp: xp,
            destroyedStructures: destroyedEnemyStructures,
            totalStructures: totalEnemyStructures,
            coreDamageFrac: coreDamageFrac
        )

        let text: String
        if victory {
            text = mode == .attack
                ? "🎉 ПОБЕДА! База врага сокрушена!"
                : "🛡️ Рейд отбит! Деревня спасена!"
        } else {
            if mode == .attack {
                text = "💔 Поражение… Коты отступили."
            } else {
                let houseAlive = structures.contains { $0.team == .player && $0.isCore && $0.isAlive }
                text = houseAlive
                    ? "🐾 Грабители отступили, забрав своё."
                    : "💔 Дом разрушен…"
            }
        }
        addEvent(victory ? .victory : .defeat, text, V2(20, 20))
    }
}
