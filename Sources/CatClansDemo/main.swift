import Foundation
import CatClansKit

// 🐾 «КотоКланы» — консольное демо.
// Запуск: swift run CatClansDemo
// Имитирует вечер в кошачьей деревне: сбор ресурсов, стройка,
// обучение армии, атака вражеской базы и оборона от рейда.

let seed: UInt64 = 20260926

func line(_ s: String = "") { print(s) }
func hr() { print(String(repeating: "─", count: 58)) }

func fmtClock(_ t: TimeInterval) -> String {
    let total = Int(t)
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)ч \(m)м" }
    let s = total % 60
    return m > 0 ? "\(m)м \(s)с" : "\(s)с"
}

func printVillage(_ state: GameState, title: String) {
    hr()
    print("🏘️ \(title) · деревня провозглашает \(fmtClock(state.gameTime))")
    hr()
    print("  Запасы: \(state.resources.display)")
    var prod: [String] = []
    for r in Resource.allCases {
        if let v = state.productionPerMinute[r], v > 0 {
            prod.append("\(r.emoji) +\(String(format: "%.0f", v))/мин")
        }
    }
    print("  Производство: \(prod.isEmpty ? "—" : prod.joined(separator: "  "))")
    let xp = state.xpProgress
    print("  Уровень игрока: \(state.playerLevel)  (XP \(xp.current)/\(xp.needed))")
    print("  Дом котов: ур. \(state.homeLevel), HP \(Int(state.homeHP))/\(state.homeMaxHP)")
    print("  Армия: \(state.armySize)/\(state.armyCapacity)")
    let roster = UnitTable.playerUnits.compactMap { u -> String? in
        let n = state.armyCount(u)
        return n > 0 ? "\(u.emoji)×\(n)" : nil
    }
    print("  Бойцы: \(roster.isEmpty ? "—" : roster.joined(separator: "  "))")
    if !state.queue.isEmpty {
        let q = state.queue.map { j in "\(j.unit.emoji) \(j.unit.ruName) (осталось \(Int(j.remaining))с)" }
        print("  Очередь: \(q.joined(separator: "  "))")
    }
    for b in state.buildings.sorted(by: { $0.slot < $1.slot }) {
        print("  \(b.type.emoji) \(b.type.ruName) — ур. \(b.level)")
    }
    hr()
}

/// Ждём, пока ресурсов хватит на `cost` (пропускаем время по 30 минут).
func ensure(_ state: inout GameState, _ cost: ResourceAmounts) {
    var guardCount = 0
    while !state.resources.canAfford(cost) && guardCount < 500 {
        _ = state.advance(dt: 30 * 60)
        guardCount += 1
    }
}

/// Печать событий боя по мере наступления.
func stream(_ sim: BattleSim, lastID: inout Int) {
    for e in sim.events where e.id > lastID {
        if e.kind != .start {
            print(String(format: "   [%@] %@", fmtClock(e.t), e.text))
        }
    }
    if let last = sim.events.last {
        lastID = last.id
    }
}

func runAttack(_ state: inout GameState, difficulty: Int) {
    let enemy = EnemyGenerator.base(difficulty: difficulty, seed: state.seed)
    line()
    print("⚔️  Атака: \(enemy.emoji) \(enemy.name) (сложность \(difficulty))")
    let defSummary = enemy.defenders.map { "\(UnitTable.def($0.unit).emoji)×\($0.count)" }.joined(separator: "  ")
    let towerSummary = enemy.towers.map { "\(BuildingTable.def($0.type).emoji) ур.\($0.level)" }.joined(separator: "  ")
    print("   Защита: \(defSummary) \(towerSummary.isEmpty ? "" : "+ " + towerSummary)")
    print("   Добыча: \(enemy.loot.display)   Опыт: +\(enemy.xp)")
    guard let sim = BattleSim(state: state, enemy: enemy, mode: .attack, seed: state.seed) else {
        print("   Армия пуста — сначала обучите котов в Академии!")
        return
    }
    var lastID = 0
    stream(sim, lastID: &lastID)
    while !sim.finished {
        sim.step()
        stream(sim, lastID: &lastID)
    }
    guard let r = sim.result else { return }
    line()
    if r.victory {
        print("🎉 ПОБЕДА за \(fmtClock(r.duration))! Строек разрушено: \(r.destroyedStructures)/\(r.totalStructures)")
    } else {
        print("💔 ПОРАЖЕНИЕ за \(fmtClock(r.duration)). Строек разрушено: \(r.destroyedStructures)/\(r.totalStructures)")
    }
    print("   Добыча: \(r.loot.display)   Опыт: +\(r.xp)")
    state.applyAttackResult(r)
}

func runRaid(_ state: inout GameState) {
    let raid = EnemyGenerator.raid(playerLevel: state.playerLevel, seed: state.seed &+ 777)
    line()
    print("🚨 РЕЙД: \(raid.name) (сила: \(raid.difficulty))")
    let defSummary = raid.defenders.map { "\(UnitTable.def($0.unit).emoji)×\($0.count)" }.joined(separator: "  ")
    print("   Рейдеры: \(defSummary)")
    guard let sim = BattleSim(state: state, enemy: raid, mode: .defense, seed: state.seed &+ 778) else { return }
    var lastID = 0
    stream(sim, lastID: &lastID)
    while !sim.finished {
        sim.step()
        stream(sim, lastID: &lastID)
    }
    guard let r = sim.result else { return }
    let note = state.applyDefenseResult(r)
    print(note)
    print("   Дом: HP \(Int(state.homeHP))/\(state.homeMaxHP), опыт: +\(r.xp)")
}

// MARK: - Сценарий вечера

line()
print("   🐾  К О Т О К Л А Н Ы  🐾")
print("   Консольное демо: один вечер в кошачьей деревне")
line()

var state = GameState.newGame(seed: seed)
printVillage(state, title: "Основание деревни")

// ── Тихие часы ───────────────────────────────────────────────────────────
line()
print("☀️  Проходит 2 часа: коты ловят рыбу и варят сметану.")
_ = state.advance(dt: 2 * 3600)
printVillage(state, title: "Два часа спустя")

print("🔨 Строим вторую Рыбную ловушку…")
let r1 = state.build(.fishTrap)
print("   \(r1.message)")
ensure(&state, ResourceAmounts(fish: 60))
let r2 = state.build(.wall)
print("   \(r2.message)")

print("🎓 Отправляем на обучение: 2 котят и боевого кота.")
let t1 = state.train(.kitten);  print("   \(t1.message)")
let t2 = state.train(.warrior); print("   \(t2.message)")
let t3 = state.train(.kitten);  print("   \(t3.message)")
line()
print("⏳ Проходит 10 минут: коты отрабатывают приёмы.")
let trainEvents = state.advance(dt: 10 * 60)
for e in trainEvents {
    if case .trainingFinished(let u) = e {
        print("   ✅ \(u.emoji) \(u.ruName) готов к бою!")
    }
}
printVillage(state, title: "Армия собрана")

// ── Первая атака ─────────────────────────────────────────────────────────
runAttack(&state, difficulty: 1)

// ── Ночной рейд ──────────────────────────────────────────────────────────
line()
print("🌙 Проходит 10 минут… из темноты слышны шаги.")
_ = state.advance(dt: 10 * 60)
if state.raidReady {
    runRaid(&state)
}

// ── Следующее утро ───────────────────────────────────────────────────────
line()
print("🌅 Утро. Решаем подрасти: Дом котов до 2 уровня.")
ensure(&state, BuildingTable.upgradeCost(.home, toLevel: 2))
let u1 = state.upgrade(slot: GameState.homeSlot)
print("   \(u1.message)")

print("🔨 Строим Полку игрушек (пряжа появилась в экономике).")
let b2 = state.build(.toyShelf)
print("   \(b2.message)")

print("🎓 Обучаем мышелова-стрелка и второго боевого кота.")
_ = state.train(.mouser)
_ = state.train(.warrior)
line()
print("⏳ Проходит 1 час.")
let trainEvents2 = state.advance(dt: 3600)
for e in trainEvents2 {
    if case .trainingFinished(let u) = e {
        print("   ✅ \(u.emoji) \(u.ruName) готов к бою!")
    }
}
printVillage(state, title: "Дом 2 уровня")

runAttack(&state, difficulty: 2)

// ── Ещё один рейд ────────────────────────────────────────────────────────
line()
print("🌙 Проходит 10 минут… опять чужие шаги.")
_ = state.advance(dt: 10 * 60)
if state.raidReady {
    runRaid(&state)
}

// ── Вечер: дом 3 уровня ─────────────────────────────────────────────────
line()
print("🌆 Вечер. Время становиться серьёзной деревней.")
ensure(&state, BuildingTable.upgradeCost(.home, toLevel: 3))
let u2 = state.upgrade(slot: GameState.homeSlot)
print("   \(u2.message)")
ensure(&state, BuildingTable.buildCost(.workshop))
let b3 = state.build(.workshop)
print("   \(b3.message)")
ensure(&state, BuildingTable.buildCost(.cannon))
let b4 = state.build(.cannon)
print("   \(b4.message)")

print("🎓 В академии начинают обучать кота-чародея.")
_ = state.train(.wizard)
line()
print("⏳ Проходит 1 час.")
let trainEvents3 = state.advance(dt: 3600)
for e in trainEvents3 {
    if case .trainingFinished(let u) = e {
        print("   ✅ \(u.emoji) \(u.ruName) готов к бою!")
    }
}
printVillage(state, title: "Дом 3 уровня")

runAttack(&state, difficulty: 3)

// ── Финал ────────────────────────────────────────────────────────────────
line()
print("🌟 Итог вечера: деревня пережила атаки, рейды и выросла.")
line()
print("💾 Сохранение (JSON), первые 220 символов:")
if let data = try? JSONEncoder().encode(state) {
    let s = String(data: data, encoding: .utf8) ?? ""
    print("   \(String(s.prefix(220)))…")
    print("   (всего \(data.count) байт)")
}
line()
print("🐈 Дальше — за вами: строите, тренируете, мурчите.")
line()
