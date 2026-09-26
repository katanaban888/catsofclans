import XCTest
import CatClansKit

final class GameStateTests: XCTestCase {

    func testTablesComplete() {
        for u in UnitID.allCases {
            XCTAssertNotNil(UnitTable.defs[u], "нет статистики для \(u.rawValue)")
        }
        for b in BuildingType.allCases {
            XCTAssertNotNil(BuildingTable.defs[b], "нет описания для \(b.rawValue)")
        }
    }

    func testNewGame() {
        let s = GameState.newGame(seed: 42)
        XCTAssertEqual(s.homeLevel, 1)
        XCTAssertEqual(s.homeMaxHP, 1000)
        XCTAssertEqual(s.homeHP, 1000)
        XCTAssertEqual(s.armyCapacity, 4, "Академия 1 ур. → 4 места")
        XCTAssertEqual(s.buildings.count, 5)
        XCTAssertEqual(s.resources.fish, 150)
        XCTAssertEqual(s.playerLevel, 1)
    }

    func testProduction() {
        var s = GameState.newGame(seed: 42)
        let fish0 = s.resources.fish
        _ = s.advance(dt: 60)
        XCTAssertEqual(s.resources.fish, fish0 + 10, "ловушка 1 ур. = 10 рыбы/мин")
        _ = s.advance(dt: 60)
        XCTAssertEqual(s.resources.fish, fish0 + 20)
    }

    func testProductionScalesWithLevelAndCount() {
        var s = GameState.newGame(seed: 42)
        _ = s.build(.fishTrap)
        // Две ловушки 1 ур. → 20/мин
        let fish0 = s.resources.fish
        _ = s.advance(dt: 120)
        XCTAssertEqual(s.resources.fish, fish0 + 40)
        // Улучшаем вторую ловушку до 2 ур. → 30/мин.
        s.resources.fish = 10_000
        let slots = s.buildings.filter { $0.type == .fishTrap }.map { $0.slot }
        XCTAssertTrue(s.upgrade(slot: slots[slots.count - 1]).isSuccess)
        let levels = s.buildings.filter { $0.type == .fishTrap }.map { $0.level }.sorted()
        XCTAssertEqual(levels, [1, 2])
        let fish1 = s.resources.fish
        _ = s.advance(dt: 120)
        XCTAssertEqual(s.resources.fish, fish1 + 60)
    }

    func testBuildUnlockGate() {
        var s = GameState.newGame(seed: 42)
        XCTAssertFalse(s.build(.cannon).isSuccess, "пушка требует дом 3")
        XCTAssertFalse(s.build(.toyShelf).isSuccess, "полка требует дом 2")
        XCTAssertTrue(s.build(.fishTrap).isSuccess)
        XCTAssertEqual(s.buildings.count, 6)
    }

    func testUpgradeCosts() {
        let c = BuildingTable.upgradeCost(.fishTrap, toLevel: 2)
        XCTAssertEqual(c.fish, 170, "100 * 1.7")
        let h = BuildingTable.upgradeCost(.home, toLevel: 2)
        XCTAssertEqual(h.fish, 250)
        XCTAssertEqual(h.cream, 150)
        XCTAssertEqual(h.yarn, 50)
        let h4 = BuildingTable.upgradeCost(.home, toLevel: 4)
        XCTAssertEqual(h4.fish, 250 * 9)
    }

    func testUpgradeNeedsResources() {
        var s = GameState.newGame(seed: 42)
        let before = s.resources
        let r = s.upgrade(slot: GameState.homeSlot)
        XCTAssertFalse(r.isSuccess)
        XCTAssertEqual(s.resources, before, "ресурсы не должны меняться при неудаче")
    }

    func testTrainingQueue() {
        var s = GameState.newGame(seed: 42)
        let r = s.train(.kitten)
        XCTAssertTrue(r.isSuccess)
        XCTAssertEqual(s.resources.cream, 80 - 25)
        XCTAssertEqual(s.queue.count, 1)
        _ = s.advance(dt: 30)
        XCTAssertEqual(s.queue.count, 1)
        XCTAssertEqual(s.armyCount(.kitten), 0)
        _ = s.advance(dt: 40)
        XCTAssertEqual(s.queue.count, 0)
        XCTAssertEqual(s.armyCount(.kitten), 1)
    }

    func testArmyCapacity() {
        var s = GameState.newGame(seed: 42)
        s.resources.cream = 100_000
        for _ in 0..<4 {
            XCTAssertTrue(s.train(.kitten).isSuccess)
        }
        XCTAssertFalse(s.train(.kitten).isSuccess, "5-й не влезает в академию 1 ур.")
        XCTAssertEqual(s.queue.count, 4)
    }

    func testUnitUnlockGates() {
        var s = GameState.newGame(seed: 42)
        XCTAssertTrue(s.train(.warrior).isSuccess)
        s.queue = []
        s.resources = ResourceAmounts(fish: 9999, cream: 9999, yarn: 9999, mouse: 9)
        XCTAssertFalse(s.train(.mouser).isSuccess, "мышелов требует дом 2")
        XCTAssertFalse(s.train(.tiger).isSuccess, "тигр требует дом 4")
    }

    func testLevels() {
        var s = GameState.newGame(seed: 42)
        XCTAssertEqual(s.playerLevel, 1)
        _ = s.gainXP(39)
        XCTAssertEqual(s.playerLevel, 1)
        _ = s.gainXP(1)
        XCTAssertEqual(s.playerLevel, 2)
        XCTAssertEqual(s.xpToNextLevel(2), 160)
    }

    func testOfflineCap() {
        var s = GameState.newGame(seed: 42)
        let now = s.lastSavedWall
        let sum = s.applyOffline(now: now + 2 * 24 * 3600)
        XCTAssertNotNil(sum)
        XCTAssertEqual(sum!.elapsed, 12 * 3600, "доход капается на 12 часов")
        XCTAssertEqual(sum!.gained.fish, 10 * 12 * 60, "10/мин × 720 минут")
        XCTAssertEqual(sum!.gained.cream, 6 * 12 * 60)
    }

    func testAttackResultAppliesLootAndCooldown() {
        var s = GameState.newGame(seed: 42)
        s.army[.kitten.rawValue] = 2
        let enemy = EnemyGenerator.base(difficulty: 1, seed: 5)
        guard let sim = BattleSim(state: s, enemy: enemy, mode: .attack, seed: 5) else {
            return XCTFail("бой не завёлся")
        }
        let r = sim.runToEnd()
        XCTAssertNotNil(r)
        let fishBefore = s.resources.fish
        s.applyAttackResult(r!)
        XCTAssertEqual(s.resources.fish, fishBefore + r!.loot.fish)
        XCTAssertFalse(s.attackReady)
        _ = s.advance(dt: 121)
        XCTAssertTrue(s.attackReady)
    }

    func testEmptyArmyCannotAttack() {
        let s = GameState.newGame(seed: 42)
        let enemy = EnemyGenerator.base(difficulty: 1, seed: 5)
        XCTAssertNil(BattleSim(state: s, enemy: enemy, mode: .attack, seed: 5))
    }
}
