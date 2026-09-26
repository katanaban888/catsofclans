import XCTest
import CatClansKit

final class BattleTests: XCTestCase {

    private func stateWithArmy(_ units: [UnitID], seed: UInt64 = 7) -> GameState {
        var s = GameState.newGame(seed: seed)
        for u in units {
            s.army[u.rawValue] = s.armyCount(u) + 1
        }
        return s
    }

    func testDeterminism() {
        let s1 = stateWithArmy([.kitten, .kitten, .warrior])
        let s2 = stateWithArmy([.kitten, .kitten, .warrior])
        let e1 = EnemyGenerator.base(difficulty: 1, seed: 123)
        let e2 = EnemyGenerator.base(difficulty: 1, seed: 123)
        XCTAssertEqual(e1, e2, "один seed — одна база")
        guard let sim1 = BattleSim(state: s1, enemy: e1, mode: .attack, seed: 123),
              let sim2 = BattleSim(state: s2, enemy: e2, mode: .attack, seed: 123) else {
            return XCTFail("бой не завёлся")
        }
        let r1 = sim1.runToEnd()
        let r2 = sim2.runToEnd()
        XCTAssertEqual(r1, r2, "результаты должны совпасть")
        XCTAssertEqual(sim1.events.count, sim2.events.count)
        for (a, b) in zip(sim1.events, sim2.events) {
            XCTAssertEqual(a.t, b.t)
            XCTAssertEqual(a.text, b.text)
        }
    }

    func testDifferentSeedsGiveDifferentBases() {
        let a = EnemyGenerator.base(difficulty: 2, seed: 1)
        let b = EnemyGenerator.base(difficulty: 2, seed: 5)
        // Детерминированно разные базы: 5 и 4 енота (проверено по SplitMix64).
        XCTAssertEqual(a.defenders, [UnitSpawn(unit: .raccoon, count: 5)])
        XCTAssertEqual(b.defenders, [UnitSpawn(unit: .raccoon, count: 4)])
        XCTAssertNotEqual(a, b)
    }

    func testStrongArmyWinsAndTakesFullLoot() {
        let s = stateWithArmy(Array(repeating: .tiger, count: 8))
        let enemy = EnemyGenerator.base(difficulty: 1, seed: 5)
        guard let sim = BattleSim(state: s, enemy: enemy, mode: .attack, seed: 5),
              let r = sim.runToEnd() else {
            return XCTFail("бой не прошёл")
        }
        XCTAssertTrue(r.victory)
        XCTAssertEqual(r.loot, enemy.loot, "полная победа = полный лут")
        XCTAssertEqual(r.xp, enemy.xp)
        XCTAssertEqual(r.destroyedStructures, r.totalStructures)
    }

    func testWeakArmyLoses() {
        let s = stateWithArmy([.kitten])
        let enemy = EnemyGenerator.base(difficulty: 5, seed: 9)
        guard let sim = BattleSim(state: s, enemy: enemy, mode: .attack, seed: 9),
              let r = sim.runToEnd() else {
            return XCTFail("бой не прошёл")
        }
        XCTAssertFalse(r.victory)
        XCTAssertLessThanOrEqual(r.loot.fish, enemy.loot.fish / 2)
    }

    func testBattleBounds() {
        var s = GameState.newGame(seed: 3)
        s.army[.warrior.rawValue] = 12
        s.army[.tiger.rawValue] = 4
        let enemy = EnemyGenerator.base(difficulty: 4, seed: 11)
        guard let sim = BattleSim(state: s, enemy: enemy, mode: .attack, seed: 11),
              let r = sim.runToEnd() else {
            return XCTFail("бой не прошёл")
        }
        XCTAssertLessThanOrEqual(r.duration, sim.timeLimit + 0.2)
        for u in sim.units {
            XCTAssertFalse(u.pos.x.isNaN || u.pos.y.isNaN, "NaN в позиции")
            XCTAssertFalse(u.pos.x.isInfinite || u.pos.y.isInfinite)
            XCTAssertTrue(u.pos.x >= 0 && u.pos.x <= 40)
            XCTAssertTrue(u.pos.y >= 0 && u.pos.y <= 40)
        }
        for st in sim.structures {
            XCTAssertGreaterThanOrEqual(st.hp, 0)
            XCTAssertLessThanOrEqual(st.hp, st.maxHP)
        }
    }

    func testSurrender() {
        let s = stateWithArmy([.warrior, .warrior])
        let enemy = EnemyGenerator.base(difficulty: 1, seed: 77)
        guard let sim = BattleSim(state: s, enemy: enemy, mode: .attack, seed: 77) else {
            return XCTFail("бой не завёлся")
        }
        for _ in 0..<50 { sim.step() }
        sim.surrender()
        XCTAssertTrue(sim.finished)
        XCTAssertNotNil(sim.result)
        XCTAssertFalse(sim.result!.victory)
    }

    func testDefenseHoldsWithTowers() {
        var s = GameState.newGame(seed: 21)
        s.resources = ResourceAmounts(fish: 1_000_000, cream: 1_000_000, yarn: 1_000_000, mouse: 10)
        _ = s.upgrade(slot: GameState.homeSlot) // дом 2
        _ = s.upgrade(slot: GameState.homeSlot) // дом 3
        XCTAssertTrue(s.build(.cannon).isSuccess)
        XCTAssertTrue(s.build(.cannon).isSuccess)
        _ = s.upgrade(slot: GameState.homeSlot) // дом 4
        XCTAssertTrue(s.build(.sniper).isSuccess)
        let raid = EnemyGenerator.raid(playerLevel: 4, seed: 31)
        guard let sim = BattleSim(state: s, enemy: raid, mode: .defense, seed: 32),
              let r = sim.runToEnd() else {
            return XCTFail("оборона не прошла")
        }
        XCTAssertTrue(r.victory, "две пушки и снайпер должны отбить рейд 4 уровня")
        XCTAssertLessThan(r.coreDamageFrac, 0.4)
        XCTAssertGreaterThan(r.loot.mouse, 0, "награда за отбитый рейд")
    }

    func testDefenseEarlyGameSurvives() {
        // Свежая деревня без башен: дом прохудится, но не сгорит.
        let s = GameState.newGame(seed: 22)
        let raid = EnemyGenerator.raid(playerLevel: 1, seed: 41)
        guard let sim = BattleSim(state: s, enemy: raid, mode: .defense, seed: 42),
              let r = sim.runToEnd() else {
            return XCTFail("оборона не прошла")
        }
        XCTAssertLessThan(r.coreDamageFrac, 1.0, "дом должен выдержать первый рейд")
        XCTAssertGreaterThan(r.coreDamageFrac, 0.0)
    }

    func testTrapStunsRaider() {
        var s = GameState.newGame(seed: 55)
        s.resources = ResourceAmounts(fish: 1_000_000, cream: 1_000_000, yarn: 1_000_000, mouse: 1)
        for _ in 0..<4 {
            _ = s.upgrade(slot: GameState.homeSlot) // дом 5
        }
        XCTAssertTrue(s.build(.trap).isSuccess)
        let raid = EnemyGenerator.raid(playerLevel: 2, seed: 61)
        guard let sim = BattleSim(state: s, enemy: raid, mode: .defense, seed: 62) else {
            return XCTFail("оборона не завелась")
        }
        guard let trap = sim.structures.first(where: { $0.isTrap }),
              let raider = sim.units.first(where: { $0.team == .enemy }) else {
            return XCTFail("нет ловушки или рейдеров")
        }
        // Телепортируем рейдера к ловушке и проверяем механику.
        raider.pos = trap.pos + V2(0.1, 0.1)
        sim.step()
        XCTAssertTrue(raider.isTrapped)
        XCTAssertGreaterThan(raider.stunUntil, sim.time - 0.01)
        XCTAssertTrue(sim.events.contains { $0.kind == .stun })
    }

    func testWorkshopBoostsArmy() {
        var s = GameState.newGame(seed: 33)
        s.resources = ResourceAmounts(fish: 1_000_000, cream: 1_000_000, yarn: 1_000_000, mouse: 1)
        s.army[.kitten.rawValue] = 1
        let before = s.armyStats.first!.maxHP
        _ = s.upgrade(slot: GameState.homeSlot) // дом 2
        _ = s.upgrade(slot: GameState.homeSlot) // дом 3
        XCTAssertTrue(s.build(.workshop).isSuccess)
        let after = s.armyStats.first!.maxHP
        XCTAssertGreaterThan(after, before, "Мастерская усиливает армию")
    }
}
