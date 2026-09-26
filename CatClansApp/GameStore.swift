import Foundation
import SwiftUI

// MARK: - Снимки боя (неизменяемые данные для SwiftUI)

struct UnitSnap: Identifiable, Equatable {
    let id: Int
    let team: Team
    let emoji: String
    let unit: UnitID
    let x: Double
    let y: Double
    let hp: Int
    let maxHP: Int
    let stunned: Bool
}

struct StructSnap: Identifiable, Equatable {
    let id: Int
    let team: Team
    let emoji: String
    let type: BuildingType
    let level: Int
    let x: Double
    let y: Double
    let hp: Int
    let maxHP: Int
    let isCore: Bool
    let destroyed: Bool
}

struct BattleSnapshot {
    let time: TimeInterval
    let units: [UnitSnap]
    let structures: [StructSnap]
    let events: [BattleEvent]
    let finished: Bool
    let limit: TimeInterval
}

/// Итог боя для полноэкранного листа результатов.
struct ResultPayload: Identifiable {
    let id = UUID()
    let result: BattleResult
    let mode: BattleMode
    let enemyName: String
}

// MARK: - Сохранение

enum SaveSystem {
    private static let key = "catclans.save.v1"

    static func load() -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ state: GameState) {
        var s = state
        s.lastSavedWall = Date().timeIntervalSince1970
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func wipe() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Центральный магазин игры

final class GameStore: ObservableObject {
    @Published private(set) var state: GameState
    @Published var battle: BattleSnapshot?
    @Published var battleMode: BattleMode = .attack
    @Published var battleTitle: String = ""
    @Published var result: ResultPayload?
    @Published var toast: String?
    @Published private(set) var deploymentUnits: [UnitID] = []
    @Published private(set) var awaitingDeployment = false
    @Published var speed: Int = 1
    @Published var paused: Bool = false
    @Published var offline: OfflineSummary?
    @Published var selectedBuilding: PlacedBuilding?
    @Published var placingBuilding: BuildingType?
    @Published var placementSlot: Int?
    @Published var battleLoot = ResourceAmounts.zero
    @Published var showBuild = false
    @Published var showArmy = false
    @Published var showAttack = false
    @Published var showSettings = false
    @Published var showResetConfirm = false

    private var sim: BattleSim?
    private var villageTimer: Timer?
    private var battleTimer: Timer?
    private var toastWork: DispatchWorkItem?
    private var saveTick = 0

    init() {
        if let loaded = SaveSystem.load() {
            state = loaded
            state.migrateVillageGrid()
            let now = Date().timeIntervalSince1970
            if let s = state.applyOffline(now: now) {
                offline = s
            }
        } else {
            state = GameState.newGame(seed: UInt64(Date().timeIntervalSince1970) &* 2654435761)
        }
        startVillageTimer()
    }

    // MARK: Таймеры

    private func startVillageTimer() {
        villageTimer?.invalidate()
        villageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.villageTick()
        }
    }

    private func villageTick() {
        guard battle == nil else { return }
        let events = state.advance(dt: 1)
        for e in events {
            switch e {
            case .trainingFinished(let u):
                showToast("\(u.ruName) готов к бою!")
            default:
                break
            }
        }
        if state.raidReady {
            startRaid()
        }
        saveTick += 1
        if saveTick >= 10 {
            saveTick = 0
            save()
        }
    }

    private func startBattleTimer() {
        battleTimer?.invalidate()
        battleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.battleTick()
        }
    }

    private func battleTick() {
        guard let s = sim else { return }
        if !s.finished && !paused {
            for _ in 0..<speed {
                s.step()
                if s.finished { break }
            }
        }
        publishBattle()
        if s.finished {
            finishBattle()
        }
    }

    private func publishBattle() {
        guard let s = sim else { return }
        deploymentUnits = s.deployQueue.map { $0.id }
        awaitingDeployment = s.awaitingDeployment
        let unitSnaps = s.units.map { u in
            UnitSnap(
                id: u.id,
                team: u.team,
                emoji: u.stats.id.emoji,
                unit: u.stats.id,
                x: u.pos.x,
                y: u.pos.y,
                hp: u.hp,
                maxHP: u.stats.maxHP,
                stunned: s.time < u.stunUntil
            )
        }
        let structSnaps = s.structures.map { st in
            StructSnap(
                id: st.id,
                team: st.team,
                emoji: st.emoji,
                type: st.type,
                level: 1,
                x: st.pos.x,
                y: st.pos.y,
                hp: st.hp,
                maxHP: st.maxHP,
                isCore: st.isCore,
                destroyed: st.hp <= 0
            )
        }
        let recent = Array(s.events.suffix(6))
        battle = BattleSnapshot(
            time: s.time,
            units: unitSnaps,
            structures: structSnaps,
            events: recent,
            finished: s.finished,
            limit: s.timeLimit
        )
    }

    // MARK: Действия

    func build(_ type: BuildingType) {
        let r = state.build(type)
        showToast(r.message)
        if r.isSuccess { save() }
    }

    func beginPlacement(_ type: BuildingType) {
        placingBuilding = type
        placementSlot = nil
        selectedBuilding = nil
        showBuild = false
    }

    func cancelPlacement() {
        placingBuilding = nil
        placementSlot = nil
    }

    func confirmPlacement() {
        guard let type = placingBuilding, let slot = placementSlot else { return }
        let result = state.build(type, at: slot)
        showToast(result.message)
        if result.isSuccess { cancelPlacement(); save() }
    }

    func upgrade(slot: Int) {
        let r = state.upgrade(slot: slot)
        showToast(r.message)
        if r.isSuccess { save() }
    }

    func train(_ unit: UnitID) {
        let r = state.train(unit)
        showToast(r.message)
        if r.isSuccess { save() }
    }

    func launchAttack(difficulty: Int) {
        guard battle == nil else { return }
        guard state.attackReady else {
            showToast("Армее нужна передышка: \(fmtTime(state.attackCooldownUntil - state.gameTime))")
            return
        }
        guard state.armySize > 0 else {
            showToast("Сначала обучите котов в Академии!")
            return
        }
        let seed = state.seed
        let village = VillageAssault.make(difficulty: difficulty, seed: seed)
        guard let s = BattleSim(state: state, village: village, seed: seed, manualDeployment: true) else {
            showToast("Армия пуста!")
            return
        }
        showAttack = false
        battleLoot = village.enemy.loot
        beginBattle(with: s, title: "Штурм деревни · \(s.enemyName)")
    }

    private func startRaid() {
        guard battle == nil else { return }
        let raid = EnemyGenerator.raid(playerLevel: state.playerLevel, seed: state.seed &+ 777)
        guard let s = BattleSim(state: state, enemy: raid, mode: .defense, seed: state.seed &+ 778) else {
            return
        }
        battleLoot = .zero
        beginBattle(with: s, title: "🛡️ \(s.enemyName)")
    }

    private func beginBattle(with s: BattleSim, title: String) {
        cancelPlacement()
        selectedBuilding = nil
        sim = s
        battleMode = s.mode
        battleTitle = title
        speed = 1
        paused = false
        publishBattle()
        startBattleTimer()
    }

    private func finishBattle() {
        guard let s = sim, let r = s.result else { return }
        battleTimer?.invalidate()
        battleTimer = nil
        if s.mode == .attack {
            state.applyAttackResult(r)
        } else {
            state.applyDefenseResult(r)
        }
        sim = nil
        deploymentUnits = []
        awaitingDeployment = false
        battle = nil
        save()
        result = ResultPayload(result: r, mode: s.mode, enemyName: s.enemyName)
    }

    func deploy(at pos: V2) {
        guard !paused else { return }
        sim?.deployNext(at: pos)
        publishBattle()
    }

    func autoDeploy() {
        sim?.deployRemaining()
        paused = false
        publishBattle()
    }

    func surrender() {
        sim?.surrender()
    }

    func setSpeed(_ s: Int) {
        speed = s
        paused = false
    }

    func togglePause() {
        paused.toggle()
    }

    func resetGame() {
        SaveSystem.wipe()
        state = GameState.newGame(seed: UInt64(Date().timeIntervalSince1970) &* 2654435761)
        showResetConfirm = false
        showToast("Новая деревня основана! 🐾")
    }

    func save() {
        SaveSystem.save(state)
    }

    func saveNow() {
        SaveSystem.save(state)
    }

    // MARK: Toast

    func showToast(_ text: String) {
        toast = text
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.toast = nil
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }
}
