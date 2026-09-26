import XCTest
import CatClansKit

final class SaveTests: XCTestCase {

    private func roundTrip(_ s: GameState) -> GameState {
        let data = try! JSONEncoder().encode(s)
        return try! JSONDecoder().decode(GameState.self, from: data)
    }

    func testNewGameRoundTrip() {
        let s = GameState.newGame(seed: 99)
        let s2 = roundTrip(s)
        XCTAssertEqual(s, s2)
    }

    func testRichStateRoundTrip() {
        var s = GameState.newGame(seed: 100)
        s.resources = ResourceAmounts(fish: 1234, cream: 56, yarn: 7, mouse: 9)
        s.army[.kitten.rawValue] = 3
        s.army[.warrior.rawValue] = 1
        s.queue.append(TrainingJob(unit: .mouser, remaining: 42, total: 180))
        s.homeHP = 512.5
        s.attackCooldownUntil = 4242
        s.lastRaidAt = 606
        s.gameTime = 9876
        _ = s.gainXP(500)
        let s2 = roundTrip(s)
        XCTAssertEqual(s, s2)
        XCTAssertEqual(s2.armyCount(.kitten), 3)
        XCTAssertEqual(s2.armyCount(.warrior), 1)
        XCTAssertEqual(s2.queue.first?.unit, .mouser)
        XCTAssertEqual(s2.playerLevel, s.playerLevel)
    }
}
