import Foundation

/// Поставленное здание в деревне.
public struct PlacedBuilding: Codable, Equatable, Hashable, Identifiable {
    public let id: Int
    public var type: BuildingType
    public var level: Int
    /// Позиция на сетке деревни, индекс = строка × gridColumns + столбец.
    public var slot: Int

    public init(id: Int, type: BuildingType, level: Int, slot: Int) {
        self.id = id
        self.type = type
        self.level = level
        self.slot = slot
    }
}

/// Работа в очереди обучения.
public struct TrainingJob: Codable, Equatable, Hashable {
    public var unit: UnitID
    /// Осталось секунд.
    public var remaining: TimeInterval
    /// Всего нужно секунд.
    public var total: TimeInterval

    public init(unit: UnitID, remaining: TimeInterval, total: TimeInterval) {
        self.unit = unit
        self.remaining = remaining
        self.total = total
    }

    public var progress: Double {
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / total))
    }
}

/// Дробная часть накопленного производства.
public struct ProductionAcc: Codable, Equatable {
    public var fish: Double = 0
    public var cream: Double = 0
    public var yarn: Double = 0
    public var mouse: Double = 0

    public subscript(r: Resource) -> Double {
        get {
            switch r {
            case .fish:  return fish
            case .cream: return cream
            case .yarn:  return yarn
            case .mouse: return mouse
            }
        }
        set {
            switch r {
            case .fish:  fish = newValue
            case .cream: cream = newValue
            case .yarn:  yarn = newValue
            case .mouse: mouse = newValue
            }
        }
    }
}

/// Полное состояние деревни. Это и есть «сейв» — сериализуется в JSON.
public struct GameState: Codable, Equatable {
    public var version: Int = 2
    /// Seed для генерации врагов.
    public var seed: UInt64 = 0
    /// Собственные «игровые» секунды с момента основания деревни.
    public var gameTime: TimeInterval = 0
    /// Стена времени (unix-секунды) последнего сохранения — для оффлайн-дохода.
    public var lastSavedWall: TimeInterval = 0
    public var playerXP: Int = 0
    public var resources: ResourceAmounts = .zero
    public var production: ProductionAcc = ProductionAcc()
    public var buildings: [PlacedBuilding] = []
    /// Текущее HP Дома котов (максимум считается от уровня).
    public var homeHP: Double = 1000
    /// Армия. Ключ — UnitID.rawValue (надёжнее для JSON).
    public var army: [String: Int] = [:]
    /// Очередь обучения (по одному коту за раз).
    public var queue: [TrainingJob] = []
    /// До какого игрового времени действует перерыв между атаками.
    public var attackCooldownUntil: TimeInterval = 0
    /// Игровое время последнего рейда по нам.
    public var lastRaidAt: TimeInterval = 0
    /// Период рейдов, секунд.
    public var raidInterval: TimeInterval = 600

    // MARK: - Создание

    /// Новая деревня: дом, две фермы, академия и забор.
    public static func newGame(seed: UInt64) -> GameState {
        var s = GameState()
        s.seed = seed
        s.resources = ResourceAmounts(fish: 150, cream: 80, yarn: 30, mouse: 5)
        s.buildings = [
            PlacedBuilding(id: 1, type: .home, level: 1, slot: GameState.homeSlot),
            PlacedBuilding(id: 2, type: .fishTrap, level: 1, slot: homeSlot - 1),
            PlacedBuilding(id: 3, type: .creamBarrel, level: 1, slot: homeSlot + 1),
            PlacedBuilding(id: 4, type: .academy, level: 1, slot: homeSlot + gridColumns),
            PlacedBuilding(id: 5, type: .wall, level: 1, slot: homeSlot + gridColumns - 1),
        ]
        s.homeHP = Double(BuildingTable.maxHP(.home, level: 1))
        s.lastSavedWall = Date().timeIntervalSince1970
        return s
    }

    // MARK: - Сетка

    /// Сетка деревни 9×7.
    public static let gridColumns = 9
    public static let gridRows = 7
    public static let slotCount = gridColumns * gridRows
    /// Дом котов стоит по центру.
    public static let homeSlot = (gridRows / 2) * gridColumns + gridColumns / 2

    /// Порядок заселения свободных участков: спиралью от центра.
    public static let slotBuildOrder: [Int] = {
        var slots = [homeSlot]
        var x = gridColumns / 2
        var y = gridRows / 2
        var length = 1
        let directions = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        var direction = 0
        while slots.count < slotCount {
            for _ in 0..<2 {
                let delta = directions[direction % 4]
                for _ in 0..<length {
                    x += delta.0
                    y += delta.1
                    if (0..<gridColumns).contains(x) && (0..<gridRows).contains(y) {
                        slots.append(y * gridColumns + x)
                    }
                }
                direction += 1
            }
            length += 1
        }
        return slots
    }()

    /// Recenter legacy 5×4 saves without changing building IDs or levels.
    public mutating func migrateVillageGrid() {
        guard version < 2 else { return }
        for i in buildings.indices {
            let slot = buildings[i].slot
            buildings[i].slot = (slot / 5 + 2) * Self.gridColumns + slot % 5 + 2
        }
        version = 2
    }

    public static func slotColumn(_ slot: Int) -> Int { slot % gridColumns }
    public static func slotRow(_ slot: Int) -> Int { slot / gridColumns }

    // MARK: - Считываемые величины

    public var homeLevel: Int {
        return buildings.first(where: { $0.type == .home })?.level ?? 1
    }

    public var workshopLevel: Int {
        let l = buildings.first(where: { $0.type == .workshop })?.level ?? 0
        return max(1, l)
    }

    public var academyLevel: Int {
        return buildings.first(where: { $0.type == .academy })?.level ?? 0
    }

    public var homeMaxHP: Int {
        return BuildingTable.maxHP(.home, level: homeLevel)
    }

    /// Вместимость армии: 2 + 2×уровень Академии.
    public var armyCapacity: Int {
        return 2 + 2 * academyLevel
    }

    public var armySize: Int {
        return army.values.reduce(0, +)
    }

    public func armyCount(_ u: UnitID) -> Int {
        return army[u.rawValue, default: 0]
    }

    /// Боевые характеристики всей текущей армии (с бонусом Мастерской усов).
    /// Порядок детерминирован — важна для воспроизводимости боя.
    public var armyStats: [UnitStats] {
        let scale = 1 + 0.12 * Double(workshopLevel - 1)
        var out: [UnitStats] = []
        for (key, count) in army {
            guard let u = UnitID(rawValue: key) else { continue }
            for _ in 0..<count {
                out.append(UnitStats(id: u, hpScale: scale, dmgScale: scale))
            }
        }
        out.sort { $0.id.rawValue < $1.id.rawValue }
        return out
    }

    /// Производство в минуту по всем зданиям.
    public var productionPerMinute: [Resource: Double] {
        var out: [Resource: Double] = [:]
        for b in buildings {
            let p = BuildingTable.production(b.type, level: b.level)
            for (r, v) in p {
                out[r, default: 0] += v
            }
        }
        return out
    }

    public var attackReady: Bool {
        return gameTime >= attackCooldownUntil
    }

    /// Сработал ли таймер рейда по нам.
    public var raidReady: Bool {
        return gameTime - lastRaidAt >= raidInterval
    }

    // MARK: - Уровень игрока

    /// XP, чтобы дойти с уровня `level` до следующего.
    public func xpToNextLevel(_ level: Int) -> Int {
        return 40 * level * level
    }

    public var playerLevel: Int {
        var level = 1
        var xp = playerXP
        while level < 30 && xp >= xpToNextLevel(level) {
            xp -= xpToNextLevel(level)
            level += 1
        }
        return level
    }

    /// (текущий XP в пределах уровня, сколько нужно).
    public var xpProgress: (current: Int, needed: Int) {
        var level = 1
        var xp = playerXP
        while level < 30 && xp >= xpToNextLevel(level) {
            xp -= xpToNextLevel(level)
            level += 1
        }
        return (xp, xpToNextLevel(level))
    }

    /// Начислить XP. Возвращает, сколько уровней поднято.
    @discardableResult
    public mutating func gainXP(_ amount: Int) -> Int {
        let before = playerLevel
        playerXP += max(0, amount)
        return playerLevel - before
    }

    // MARK: - Время

    /// Продвинуть деревню на dt секунд: производство, обучение,
    /// регенерация Дома котов. Возвращает события.
    public mutating func advance(dt: TimeInterval) -> [GameEvent] {
        var events: [GameEvent] = []
        let d = max(0, dt)
        gameTime += d

        // Производство.
        let perMin = productionPerMinute
        for (r, rate) in perMin where rate > 0 {
            production[r] += rate * d / 60.0
            let whole = Int(production[r])
            if whole > 0 {
                production[r] -= Double(whole)
                resources[r] += whole
            }
        }

        // Регенерация Дома котов: 2% максимума в секунду.
        if homeHP < Double(homeMaxHP) {
            homeHP = min(Double(homeMaxHP), homeHP + Double(homeMaxHP) * 0.02 * d)
        }

        // Очередь обучения: первые работы, которые успевают, завершаются.
        while let job = queue.first {
            if job.remaining <= d {
                setArmyCount(job.unit, armyCount(job.unit) + 1)
                queue.removeFirst()
                events.append(.trainingFinished(job.unit))
            } else {
                queue[0].remaining -= d
                break
            }
        }
        return events
    }

    /// Оффлайн-прогресс: производство и обучение, но без рейдов.
    /// Доход капается на 12 часов.
    @discardableResult
    public mutating func applyOffline(now: TimeInterval) -> OfflineSummary? {
        let elapsed = now - lastSavedWall
        lastSavedWall = now
        guard elapsed > 5 else { return nil }
        let capped = min(elapsed, 12 * 3600)
        let before = resources
        let events = advance(dt: capped)
        let trained: [UnitID] = events
            .compactMap { e -> UnitID? in
                if case .trainingFinished(let u) = e { return u }
                return nil
            }
        let gained = resources - before
        return OfflineSummary(elapsed: capped, gained: gained, trained: trained)
    }

    // MARK: - Действия

    private func nextBuildingID() -> Int {
        let m = buildings.map { $0.id }.max() ?? 0
        return m + 1
    }

    private func nextFreeSlot() -> Int? {
        let used = Set(buildings.map { $0.slot })
        for s in Self.slotBuildOrder where !used.contains(s) {
            return s
        }
        return nil
    }

    /// Поставить новое здание 1 уровня.
    public mutating func build(_ type: BuildingType) -> GameResult {
        if type == .home {
            return .error("Дом котов не строится — он с вами с самого начала.")
        }
        let def = BuildingTable.def(type)
        guard homeLevel >= def.requiredHomeLevel else {
            return .error("Нужен Дом котов \(def.requiredHomeLevel) ур.")
        }
        guard let slot = nextFreeSlot() else {
            return .error("Нет свободных участков в деревне.")
        }
        let cost = BuildingTable.buildCost(type)
        guard resources.canAfford(cost) else {
            return .error("Не хватает ресурсов: нужно \(cost.display).")
        }
        resources.spend(cost)
        buildings.append(PlacedBuilding(id: nextBuildingID(), type: type, level: 1, slot: slot))
        _ = gainXP(6)
        return .ok("Построено: \(def.emoji) \(def.ruName)")
    }

    /// Улучшить здание на участке `slot`.
    public mutating func upgrade(slot: Int) -> GameResult {
        guard let idx = buildings.firstIndex(where: { $0.slot == slot }) else {
            return .error("Здание не найдено.")
        }
        let b = buildings[idx]
        let def = BuildingTable.def(b.type)
        guard b.level < def.maxLevel else {
            return .error("Уже максимум уровня.")
        }
        let cost = BuildingTable.upgradeCost(b.type, toLevel: b.level + 1)
        guard resources.canAfford(cost) else {
            return .error("Не хватает ресурсов: нужно \(cost.display).")
        }
        resources.spend(cost)
        buildings[idx].level += 1
        if b.type == .home {
            // Ремонт и наращивание после улучшения.
            homeHP = min(Double(homeMaxHP), homeHP + 400)
        }
        _ = gainXP(6 * buildings[idx].level)
        return .ok("Обновлено: \(def.emoji) \(def.ruName) → ур. \(buildings[idx].level)")
    }

    /// Поставить юнита в очередь обучения.
    public mutating func train(_ unit: UnitID) -> GameResult {
        guard unit.isPlayerUnit else {
            return .error("Этого вы не обучаете.")
        }
        let def = UnitTable.def(unit)
        guard homeLevel >= def.requiredHomeLevel else {
            return .error("Нужен Дом котов \(def.requiredHomeLevel) ур.")
        }
        guard academyLevel >= def.requiredAcademyLevel else {
            return .error("Нужна Академия котов \(def.requiredAcademyLevel) ур.")
        }
        guard armySize + queue.count < armyCapacity else {
            return .error("Армия заполнена (\(armySize)/\(armyCapacity)).")
        }
        // Мастерская усов ускоряет обучение на 5% за уровень.
        let time = def.trainingTime * max(0.5, 1 - 0.05 * Double(workshopLevel - 1))
        guard resources.canAfford(def.trainingCost) else {
            return .error("Не хватает ресурсов: нужно \(def.trainingCost.display).")
        }
        resources.spend(def.trainingCost)
        queue.append(TrainingJob(unit: unit, remaining: time, total: time))
        return .ok("Обучение началось: \(unit.emoji) \(unit.ruName)")
    }

    private mutating func setArmyCount(_ u: UnitID, _ n: Int) {
        if n > 0 {
            army[u.rawValue] = n
        } else {
            army[u.rawValue] = nil
        }
    }

    // MARK: - Результаты боёв

    /// Записать результат атаки на вражескую базу.
    public mutating func applyAttackResult(_ result: BattleResult) {
        resources.add(result.loot)
        _ = gainXP(result.xp)
        // Два минуты передышки между атаками.
        attackCooldownUntil = gameTime + 120
    }

    /// Записать результат оборонительного рейда.
    /// Возвращает строку-итог для интерфейса.
    @discardableResult
    public mutating func applyDefenseResult(_ result: BattleResult) -> String {
        let dmg = Double(result.coreDamageFrac) * Double(homeMaxHP)
        homeHP -= dmg
        _ = gainXP(result.xp)
        lastRaidAt = gameTime
        if result.victory {
            resources.add(result.loot)
            if homeHP > 0 {
                return "Рейд отбит! Дом уцелел."
            }
        }
        if homeHP <= 0 {
            // Дом сгорел: грабители уносят 20% запасов.
            resources = resources.scaled(0.8)
            homeHP = Double(homeMaxHP) * 0.35
            return "Дом котов разрушен! Грабители унесли 20% запасов."
        }
        return "Вас продавили, но дом устоял."
    }
}
