import XCTest
import CatClansKit

final class VillageAssaultTests: XCTestCase {
    func testConfigurationIsDeterministicAndOnlyContainsCatGarrisons() {
        for difficulty in 1...5 {
            let a = VillageAssault.make(difficulty: difficulty, seed: 17)
            XCTAssertEqual(a, VillageAssault.make(difficulty: difficulty, seed: 17))
            XCTAssertTrue(a.enemy.defenders.allSatisfy { $0.unit.isPlayerUnit })
            XCTAssertEqual(a.buildings.count, 7)
            XCTAssertEqual(a.enemy.loot, EnemyGenerator.base(difficulty: difficulty, seed: 17).loot)
        }
    }

    func testAdditionalTargetsDoNotConsumeRNGOrChangeLegacySpawnPositions() {
        let village = VillageAssault.make(difficulty: 4, seed: 9)
        let legacy = BattleSim(playerUnits: [UnitStats(id: .kitten)], playerStructures: [],
                               enemy: village.enemy, mode: .attack, seed: 9)
        let assault = BattleSim(playerUnits: [UnitStats(id: .kitten)], playerStructures: [],
                                enemy: village.enemy, mode: .attack, seed: 9,
                                villageBuildings: village.buildings)
        XCTAssertEqual(legacy.units.map { $0.pos }, assault.units.map { $0.pos })
        XCTAssertEqual(legacy.structures.map { $0.pos },
                       Array(assault.structures.prefix(legacy.structures.count)).map { $0.pos })
        XCTAssertEqual(assault.structures.count, legacy.structures.count + 7)
        XCTAssertTrue(assault.structures.filter { [.yarnMill, .bivouac].contains($0.type) }
            .allSatisfy { !$0.isTower && !$0.isTrap })
    }

    func testManualReserveAutomaticAndHeadlessAssaultStillWork() {
        var state = GameState.newGame(seed: 42)
        state.army[UnitID.tiger.rawValue] = 8
        let village = VillageAssault.make(difficulty: 1, seed: 42)
        let manual = BattleSim(state: state, village: village, seed: 42)!
        let auto = BattleSim(state: state, village: village, seed: 42, manualDeployment: false)!
        XCTAssertTrue(manual.awaitingDeployment)
        manual.step()
        XCTAssertEqual(manual.time, 0)
        manual.deployRemaining()
        XCTAssertEqual(manual.units.map { $0.pos }, auto.units.map { $0.pos })
        XCTAssertEqual(manual.runToEnd(), auto.runToEnd())
        XCTAssertTrue(manual.structures.contains { $0.hp <= 0 })
    }

    func testLegacyInitializerStillHasOnlyLegacyStructuresAndAutomaticArmy() {
        var state = GameState.newGame(seed: 3)
        state.army[UnitID.kitten.rawValue] = 1
        let enemy = EnemyGenerator.base(difficulty: 1, seed: 3)
        let sim = BattleSim(state: state, enemy: enemy, mode: .attack, seed: 3)!
        XCTAssertEqual(sim.structures.count, 1)
        XCTAssertTrue(sim.units.contains { $0.team == .player })
        XCTAssertTrue(sim.deployQueue.isEmpty)
    }
}
