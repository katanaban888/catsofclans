import Foundation
import SwiftUI

struct BattleScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var showLog = false

    var body: some View {
        ZStack {
            Color.ccGrassB.ignoresSafeArea()
            if let battle = store.battle {
                VStack(spacing: 0) {
                    BattleStatusBar(battle: battle)
                    ArenaView(battle: battle)
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 4) {
                                if store.battleMode == .attack { DeploymentTray() }
                                BattleControls()
                                Button { showLog.toggle() } label: {
                                    Image(systemName: "list.bullet").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(showLog ? "Скрыть журнал" : "Журнал боя")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                            .frame(maxWidth: 540)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
                        .overlay(alignment: .leading) {
                            if showLog {
                                VStack(spacing: 0) {
                                    Button("Закрыть журнал") { showLog = false }.frame(height: 44)
                                    EventLog(events: battle.events)
                                }
                                .frame(width: 180, height: 170)
                                .background(Color.black.opacity(0.8))
                            }
                        }
                }
            }
        }
    }
}

private struct BattleStatusBar: View {
    @EnvironmentObject var store: GameStore
    let battle: BattleSnapshot

    private var destruction: Double {
        let targets = battle.structures.filter { $0.team == (store.battleMode == .attack ? .enemy : .player) }
        let total = targets.reduce(0) { $0 + $1.maxHP }
        let destroyed = targets.filter { $0.destroyed }.reduce(0) { $0 + $1.maxHP }
        return Double(destroyed) / Double(max(1, total))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(store.battleTitle).font(.system(size: 12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if store.battleMode == .attack {
                Text("Добыча до \(store.battleLoot.display)").font(.system(size: 10)).lineLimit(1)
            }
            Text("\(Int(destruction * 100))% разрушено").font(.system(size: 10))
            Text(fmtClock(battle.time)).font(.system(size: 12, weight: .bold).monospacedDigit())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Color.black.opacity(0.35))
    }
}

struct ArenaView: View {
    @EnvironmentObject var store: GameStore
    @State private var ghost: V2?
    let battle: BattleSnapshot
    private let tile: CGFloat = 20

    var body: some View {
        MapViewport(worldSize: V2(800, 800), home: V2(400, 340), initialZoom: 1.4,
                    onTap: deploy, onPreview: preview) {
            ZStack(alignment: .topLeading) {
                VillageBattleScenery()
                if !store.deploymentUnits.isEmpty {
                    Rectangle().fill(Color.ccGood.opacity(0.12))
                        .frame(width: 800, height: 400).position(x: 400, y: 600)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 400)); p.addLine(to: CGPoint(x: 800, y: 400))
                    }.stroke(Color.ccGood.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                }
                ForEach(battle.structures) { structure in
                    BattleStructureView(snap: structure, tile: tile)
                        .position(x: CGFloat(structure.x) * tile, y: CGFloat(structure.y) * tile)
                }
                ForEach(battle.units.filter { $0.hp > 0 }) { unit in
                    BattleUnitView(snap: unit, tile: tile)
                        .position(x: CGFloat(unit.x) * tile, y: CGFloat(unit.y) * tile)
                }
                if let point = ghost, let unit = store.deploymentUnits.first {
                    UnitSpriteView(unit: unit, size: tile * 1.4)
                        .opacity(0.65)
                        .position(x: CGFloat(point.x) * tile, y: CGFloat(point.y) * tile)
                }
            }
        }
        .accessibilityLabel("Деревня. Тап — высадка в нижней половине, движение — камера")
        .accessibilityAction(named: Text("Высадить следующего кота в центре")) { store.deploy(at: V2(20, 35)) }
    }

    private func deploy(_ world: V2) {
        guard let point = BattleMapInput.deploymentPoint(world: world) else { return }
        store.deploy(at: point)
    }

    private func preview(_ world: V2?) {
        guard !store.paused, !store.deploymentUnits.isEmpty, let world = world else { ghost = nil; return }
        ghost = BattleMapInput.deploymentPoint(world: world)
    }
}

private struct DeploymentTray: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Резерв").font(.system(size: 10))
                Text("\(store.deploymentUnits.count)").font(.caption.bold())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UnitTable.playerUnits, id: \.self) { unit in
                        let count = store.deploymentUnits.filter { $0 == unit }.count
                        if count > 0 {
                            HStack(spacing: 2) {
                                UnitSpriteView(unit: unit, size: 28)
                                Text("×\(count)").font(.caption.bold())
                            }
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(store.deploymentUnits.first == unit ? Color.ccGood.opacity(0.35) : Color.clear))
                            .accessibilityLabel("\(unit.ruName), осталось \(count)")
                        }
                    }
                }
            }
            Button { store.autoDeploy() } label: {
                VStack(spacing: 0) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 16))
                    Text("Авто").font(.system(size: 10))
                }.frame(width: 44, height: 44)
            }
                .disabled(store.deploymentUnits.isEmpty)
                .accessibilityLabel("Высадить всех оставшихся котов")
        }
        .foregroundColor(.white)

    }
}

struct BattleStructureView: View {
    let snap: StructSnap
    let tile: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            BuildingSpriteView(type: snap.type, level: snap.level, size: tile * 3.3)
                .opacity(snap.destroyed ? 0.25 : 1)
                .saturation(snap.destroyed ? 0 : 1)
                .overlay(
                    snap.destroyed
                        ? SpriteView(asset: "fx_boom", fallbackEmoji: "💥", size: tile * 2.2)
                        : nil
                )
            if !snap.destroyed {
                HPBar(frac: Double(snap.hp) / Double(max(1, snap.maxHP)), width: tile * 2.2)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !snap.destroyed && snap.hp < snap.maxHP / 2 {
                Image(systemName: "bolt.fill").foregroundColor(.orange)
                    .font(.system(size: tile)).rotationEffect(.degrees(18))
            }
        }
        .accessibilityLabel("\(snap.type.ruName), \(snap.destroyed ? "разрушено" : "HP \(snap.hp)")")
    }
}

struct BattleUnitView: View {
    let snap: UnitSnap
    let tile: CGFloat

    var body: some View {
        UnitSpriteView(unit: snap.unit, size: tile * 1.4, team: snap.team)
            .overlay(alignment: .bottom) {
                HPBar(frac: Double(snap.hp) / Double(max(1, snap.maxHP)), width: tile * 1.3)
                    .offset(y: 6)
            }
            .overlay(alignment: .top) {
                if snap.stunned {
                    Image(systemName: "sparkles").foregroundColor(.yellow).font(.system(size: tile * 0.6))
                }
            }
    }
}

// MARK: - Лента событий

struct EventLog: View {
    let events: [BattleEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Журнал боя")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.7))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(events.reversed()) { e in
                        HStack(alignment: .top, spacing: 5) {
                            Text(fmtClock(e.t))
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundColor(.white.opacity(0.5))
                            Text(e.text)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                    }
                }
                .padding(8)
            }
        }
        .padding(.leading, 8)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Управление боем

struct BattleControls: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 2) {
            Button { store.togglePause() } label: {
                Image(systemName: store.paused ? "play.fill" : "pause.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel(store.paused ? "Продолжить" : "Пауза")
            Menu {
                ForEach([1, 2, 4], id: \.self) { speed in
                    Button("\(speed)×") { store.setSpeed(speed) }
                }
            } label: {
                Text("\(store.speed)×").font(.caption.bold()).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Скорость боя, сейчас \(store.speed)")
            Button { store.surrender() } label: {
                VStack(spacing: 0) {
                    Image(systemName: "flag.fill").font(.system(size: 16))
                    Text("Уйти").font(.system(size: 10))
                }.frame(width: 44, height: 44)
            }
            .accessibilityLabel("Отступить")
        }
        .buttonStyle(.plain)
    }
}
