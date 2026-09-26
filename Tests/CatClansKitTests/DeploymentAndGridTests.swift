import XCTest
import CatClansKit

final class DeploymentAndGridTests: XCTestCase {
    private func attack(manual: Bool = true) -> BattleSim {
        var state = GameState.newGame(seed: 7)
        state.army[UnitID.kitten.rawValue] = 2
        state.army[UnitID.warrior.rawValue] = 1
        return BattleSim(state: state, enemy: EnemyGenerator.base(difficulty: 2, seed: 123),
                         seed: 123, manualDeployment: manual)!
    }

    func testSpiralCoversGridAndStartsAtHome() {
        XCTAssertEqual(GameState.slotBuildOrder.count, GameState.slotCount)
        XCTAssertEqual(Set(GameState.slotBuildOrder), Set(0..<GameState.slotCount))
        XCTAssertEqual(GameState.slotBuildOrder.first, GameState.homeSlot)
        let state = GameState.newGame(seed: 7)
        XCTAssertEqual(Set(state.buildings.map { $0.slot }).count, state.buildings.count)
        XCTAssertTrue(state.buildings.allSatisfy { (0..<GameState.slotCount).contains($0.slot) })
    }

    func testBuildFillsEverySlot() {
        var state = GameState.newGame(seed: 7)
        state.resources = ResourceAmounts(fish: 1_000_000, cream: 1_000_000, yarn: 1_000_000, mouse: 1000)
        while state.buildings.count < GameState.slotCount {
            guard state.build(.fishTrap).isSuccess else { return XCTFail("Free slot inaccessible") }
        }
        XCTAssertEqual(Set(state.buildings.map { $0.slot }), Set(0..<GameState.slotCount))
        XCTAssertFalse(state.build(.fishTrap).isSuccess)
    }

    func testLegacyMigrationIsIdempotent() {
        var state = GameState.newGame(seed: 7)
        state.version = 1
        for (index, slot) in [7, 6, 8, 12, 11].enumerated() {
            state.buildings[index].slot = slot
        }
        state.migrateVillageGrid()
        XCTAssertEqual(state.buildings.first?.slot, GameState.homeSlot)
        let migrated = state
        state.migrateVillageGrid()
        XCTAssertEqual(state, migrated)
    }

    func testManualWaitsAndClampsInput() {
        let sim = attack()
        XCTAssertTrue(sim.awaitingDeployment)
        XCTAssertEqual(sim.deployQueue.count, 3)
        XCTAssertFalse(sim.units.contains { $0.team == .player })
        sim.step()
        XCTAssertEqual(sim.time, 0)
        XCTAssertFalse(sim.finished)
        XCTAssertFalse(sim.deployNext(at: V2(.nan, 30)))
        XCTAssertEqual(sim.deployQueue.count, 3)
        XCTAssertTrue(sim.deployNext(at: V2(-10, -10)))
        XCTAssertEqual(sim.units.last?.pos, V2(0.5, 20))
        XCTAssertTrue(sim.deployNext(at: V2(100, 100)))
        XCTAssertEqual(sim.units.last?.pos, V2(39.5, 39.5))
        XCTAssertFalse(sim.awaitingDeployment)
    }

    func testReservePreventsPrematureDefeatButNotTimeout() {
        let sim = attack()
        sim.deployNext(at: V2(20, 38))
        sim.units.filter { $0.team == .player }.forEach { $0.hp = 0 }
        sim.step()
        XCTAssertFalse(sim.finished)
        for _ in 0..<1801 { sim.step() }
        XCTAssertTrue(sim.finished)
        XCTAssertFalse(sim.deployNext(at: V2(20, 30)))
    }

    func testAutoDeploymentMatchesOriginalBattleIncludingRNG() {
        let manual = attack()
        let automatic = attack(manual: false)
        manual.deployRemaining()
        XCTAssertEqual(manual.units.map { $0.pos }, automatic.units.map { $0.pos })
        XCTAssertEqual(manual.units.map { $0.id }, automatic.units.map { $0.id })
        XCTAssertEqual(manual.structures.map { $0.pos }, automatic.structures.map { $0.pos })
        XCTAssertEqual(manual.runToEnd(), automatic.runToEnd())
        XCTAssertEqual(manual.events.map { $0.text }, automatic.events.map { $0.text })
    }

    func testManualReplayAndHeadlessCompletion() {
        let a = attack()
        let b = attack()
        for sim in [a, b] {
            sim.deployNext(at: V2(10, 30))
            for _ in 0..<10 { sim.step() }
            sim.deployNext(at: V2(30, 35))
        }
        XCTAssertEqual(a.runToEnd(), b.runToEnd())
        XCTAssertNotNil(attack().runToEnd())
    }

    func testSurrenderDuringPreparationAndDefense() {
        let sim = attack()
        sim.surrender()
        XCTAssertTrue(sim.finished)
        XCTAssertFalse(sim.deployNext(at: V2(20, 30)))
        let state = GameState.newGame(seed: 7)
        let defense = BattleSim(state: state, enemy: EnemyGenerator.raid(playerLevel: 1, seed: 7),
                                mode: .defense, seed: 7)!
        XCTAssertTrue(defense.deployQueue.isEmpty)
        XCTAssertFalse(defense.awaitingDeployment)
        XCTAssertFalse(defense.deployNext(at: V2(20, 30)))
        XCTAssertNotNil(defense.runToEnd())
    }
}
