import XCTest
import CatClansKit

final class PlacementAndEconomyTests: XCTestCase {
    private let newTypes: [BuildingType] = [.yarnMill, .mouseExpedition, .bivouac]

    private func richState(home: Int = 5) -> GameState {
        var state = GameState.newGame(seed: 42)
        state.buildings[0].level = home
        state.resources = ResourceAmounts(fish: 1_000_000, cream: 1_000_000, yarn: 1_000_000, mouse: 1000)
        return state
    }

    func testExplicitPlacementIsAtomicOnOccupiedInvalidAndUnaffordableSlots() {
        var state = richState()
        for slot in [-1, GameState.slotCount, GameState.homeSlot] {
            let before = state
            XCTAssertFalse(state.build(.fishTrap, at: slot).isSuccess)
            XCTAssertEqual(state, before)
        }
        state.resources = .zero
        let before = state
        XCTAssertFalse(state.build(.bivouac, at: 0).isSuccess)
        XCTAssertEqual(state, before)
        XCTAssertFalse(state.build(.home, at: 0).isSuccess)
        XCTAssertEqual(state, before)
    }

    func testChosenSlotAndSingleCharge() {
        var state = richState()
        let before = state.resources
        XCTAssertTrue(state.build(.yarnMill, at: 0).isSuccess)
        XCTAssertEqual(state.buildings.last?.slot, 0)
        XCTAssertEqual(state.resources, before - BuildingTable.buildCost(.yarnMill))
        let built = state
        XCTAssertFalse(state.build(.yarnMill, at: 0).isSuccess)
        XCTAssertEqual(state, built)
    }

    func testUnlockBuildUpgradeMaxLevelAndJSONForEveryNewBuilding() throws {
        for type in newTypes {
            let def = BuildingTable.def(type)
            var locked = richState(home: def.requiredHomeLevel - 1)
            let before = locked
            XCTAssertFalse(locked.build(type, at: 0).isSuccess)
            XCTAssertFalse(locked.build(type).isSuccess)
            XCTAssertEqual(locked, before)
            var state = richState(home: def.requiredHomeLevel)
            XCTAssertTrue(state.build(type, at: 0).isSuccess)
            XCTAssertEqual(state.buildings.last?.level, 1)
            for level in 2...def.maxLevel {
                let resources = state.resources
                XCTAssertTrue(state.upgrade(slot: 0).isSuccess)
                XCTAssertEqual(state.buildings.last?.level, level)
                XCTAssertEqual(state.resources, resources - BuildingTable.upgradeCost(type, toLevel: level))
            }
            let maxed = state
            XCTAssertFalse(state.upgrade(slot: 0).isSuccess)
            XCTAssertEqual(state, maxed)
            let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(decoded, state)
        }
    }

    func testUnaffordableUpgradeDoesNotChangeState() {
        for type in newTypes {
            var state = richState()
            XCTAssertTrue(state.build(type, at: 0).isSuccess)
            state.resources = .zero
            let before = state
            XCTAssertFalse(state.upgrade(slot: 0).isSuccess)
            XCTAssertEqual(state, before)
        }
    }

    func testNewBuildingsAlsoSupportAutomaticPlacement() {
        for type in newTypes {
            var state = richState()
            XCTAssertTrue(state.build(type).isSuccess)
            XCTAssertEqual(state.buildings.last?.type, type)
            XCTAssertEqual(Set(state.buildings.map { $0.slot }).count, state.buildings.count)
        }
    }

    func testYarnProductionAndUpgradeAreAdditive() {
        var state = richState()
        let old = state.productionPerMinute[.yarn, default: 0]
        XCTAssertTrue(state.build(.yarnMill, at: 0).isSuccess)
        XCTAssertEqual(state.productionPerMinute[.yarn, default: 0], old + 3)
        XCTAssertTrue(state.upgrade(slot: 0).isSuccess)
        XCTAssertEqual(state.productionPerMinute[.yarn, default: 0], old + 6)
        let before = state.resources.yarn
        _ = state.advance(dt: 60)
        XCTAssertEqual(state.resources.yarn, before + 6)
    }

    func testExpeditionIsSlowLimitedAndScalesWithUpgrade() {
        var state = richState()
        XCTAssertTrue(state.build(.mouseExpedition, at: 0).isSuccess)
        let built = state
        XCTAssertFalse(state.build(.mouseExpedition, at: 1).isSuccess)
        XCTAssertFalse(state.build(.mouseExpedition).isSuccess)
        XCTAssertEqual(state, built)
        let before = state.resources.mouse
        _ = state.advance(dt: 60)
        XCTAssertEqual(state.resources.mouse, before)
        _ = state.advance(dt: 3541)
        XCTAssertEqual(state.resources.mouse, before + 1)
        XCTAssertTrue(state.upgrade(slot: 0).isSuccess)
        XCTAssertEqual(state.productionPerMinute[.mouse, default: 0], 2.0 / 60, accuracy: 0.000001)
    }

    func testBivouacAddsCapacityButDoesNotReplaceAcademy() {
        var state = richState()
        let original = state.armyCapacity
        XCTAssertTrue(state.build(.bivouac, at: 0).isSuccess)
        XCTAssertEqual(state.armyCapacity, original + 2)
        XCTAssertTrue(state.upgrade(slot: 0).isSuccess)
        XCTAssertEqual(state.armyCapacity, original + 4)
        state.buildings.removeAll { $0.type == .academy }
        XCTAssertEqual(state.academyLevel, 0)
        XCTAssertFalse(state.train(.warrior).isSuccess)
    }

    func testLegacySaveWithoutNewFieldsRetainsCapacityAndProduction() throws {
        let old = GameState.newGame(seed: 4)
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, old)
        XCTAssertEqual(decoded.armyCapacity, 2 + 2 * decoded.academyLevel)
        XCTAssertEqual(decoded.productionPerMinute[.mouse, default: 0], 0)
        XCTAssertTrue(newTypes.allSatisfy { type in !decoded.buildings.contains { $0.type == type } })
    }

    func testEconomicBuildingsAreNotTowersAndDoNotChangeLegacyDefense() {
        let old = richState()
        var state = old
        for (slot, type) in newTypes.enumerated() {
            XCTAssertTrue(state.build(type, at: slot).isSuccess)
            XCTAssertFalse(BuildingTable.def(type).isTower)
            XCTAssertEqual(BuildingTable.def(type).trapRadius, 0)
        }
        let raid = EnemyGenerator.raid(playerLevel: 1, seed: 8)
        let a = BattleSim(state: old, enemy: raid, mode: .defense, seed: 8)!
        let b = BattleSim(state: state, enemy: raid, mode: .defense, seed: 8)!
        XCTAssertEqual(a.structures.map { $0.pos }, b.structures.map { $0.pos })
        XCTAssertEqual(a.runToEnd(), b.runToEnd())
    }
}
