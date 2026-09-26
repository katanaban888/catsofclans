import Foundation
import SwiftUI

// MARK: - Экран боя (landscape)

struct BattleScreen: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.16, blue: 0.10), Color(red: 0.06, green: 0.10, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let b = store.battle {
                VStack(spacing: 0) {
                    battleTopHUD(b)
                    HStack(spacing: 0) {
                        EventLog(events: b.events)
                            .frame(width: 128)
                        ArenaView(battle: b)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        BattleControls()
                            .frame(width: 100)
                    }
                    if store.battleMode == .attack {
                        DeploymentTray()
                    }
                }
            }
        }
    }

    private func battleTopHUD(_ b: BattleSnapshot) -> some View {
        HStack(spacing: 12) {
            Text(store.battleTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Text(fmtClock(b.time))
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(.ccAccent)
            ProgressView(value: b.time, total: max(1, b.limit))
                .tint(Color.ccAccent)
                .frame(width: 120)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
    }
}

// MARK: - Арена

struct ArenaView: View {
    @EnvironmentObject var store: GameStore
    @State private var ghost: CGPoint?
    let battle: BattleSnapshot

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / CGFloat(BattleSim.mapSize)
            let ox = (geo.size.width - side) / 2
            let oy = (geo.size.height - side) / 2
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(colors: [Color.ccTileB, Color.ccGrassB], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: side, height: side)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if !store.deploymentUnits.isEmpty {
                    Rectangle().fill(Color.ccGood.opacity(0.15))
                        .frame(width: side, height: side / 2)
                        .position(x: ox + side / 2, y: oy + side * 0.75)
                        .allowsHitTesting(false)
                }
                if let point = ghost, let unit = store.deploymentUnits.first {
                    UnitSpriteView(unit: unit, size: 32)
                        .opacity(0.65)
                        .position(point)
                        .allowsHitTesting(false)
                }

                ForEach(battle.structures) { st in
                    BattleStructureView(snap: st, tile: s)
                        .position(x: ox + st.x * s, y: oy + st.y * s)
                }
                ForEach(battle.units) { u in
                    BattleUnitView(snap: u, tile: s)
                        .position(x: ox + u.x * s, y: oy + u.y * s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !store.paused, !store.deploymentUnits.isEmpty else { return }
                    ghost = CGPoint(x: min(ox + side - s / 2, max(ox + s / 2, value.location.x)),
                                    y: min(oy + side - s / 2, max(oy + side / 2, value.location.y)))
                }
                .onEnded { value in
                    ghost = nil
                    guard side > 0,
                          value.location.x >= ox, value.location.x <= ox + side,
                          value.location.y >= oy + side / 2, value.location.y <= oy + side else { return }
                    store.deploy(at: V2(Double((value.location.x - ox) / s),
                                        Double((value.location.y - oy) / s)))
                })
            .accessibilityLabel("Поле боя. Высадка котов в нижней половине")
            .accessibilityAction(named: Text("Высадить следующего кота в центре")) {
                store.deploy(at: V2(20, 35))
            }
        }
        .padding(8)
    }
}

private struct DeploymentTray: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Осталось: \(store.deploymentUnits.count)").font(.caption.bold())
                Text(store.awaitingDeployment ? "Тапните по нижней половине — начать" : "Высаживайте подкрепление тапом")
                    .font(.system(size: 10))
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
            Button("Авто-высадка") { store.autoDeploy() }
                .font(.caption.bold())
                .padding(10)
                .background(Capsule().fill(Color.ccGood.opacity(0.6)))
                .disabled(store.deploymentUnits.isEmpty)
                .accessibilityLabel("Высадить всех оставшихся котов")
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }
}

struct BattleStructureView: View {
    let snap: StructSnap
    let tile: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            BuildingSpriteView(type: snap.type, level: snap.level, size: tile * 2.4)
                .opacity(snap.destroyed ? 0.25 : 1)
                .saturation(snap.destroyed ? 0 : 1)
                .overlay(
                    snap.destroyed
                        ? SpriteView(asset: "fx_boom", fallbackEmoji: "💥", size: tile * 1.4)
                        : nil
                )
            if !snap.destroyed {
                HPBar(frac: Double(snap.hp) / Double(max(1, snap.maxHP)), width: tile * 2.2)
            }
        }
    }
}

struct BattleUnitView: View {
    let snap: UnitSnap
    let tile: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            UnitSpriteView(unit: snap.unit, size: tile * 1.4, team: snap.team)
                .opacity(snap.hp > 0 ? 1 : 0)
                .overlay(
                    snap.stunned ? Text("💫").font(.system(size: tile * 0.8)) : nil
                )
            HPBar(frac: Double(snap.hp) / Double(max(1, snap.maxHP)), width: tile * 1.3)
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
        VStack(spacing: 14) {
            Button(action: { store.togglePause() }) {
                Image(systemName: store.paused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.paused ? "Продолжить" : "Пауза")

            HStack(spacing: 6) {
                speedBtn(1)
                speedBtn(2)
                speedBtn(4)
            }

            Button(action: { store.surrender() }) {
                VStack(spacing: 2) {
                    Image(systemName: "flag.fill").font(.subheadline)
                    Text("Сдаться").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 64, height: 48)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.ccBad.opacity(0.8)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Отступить")

            Spacer()
        }
        .padding(.trailing, 8)
    }

    private func speedBtn(_ v: Int) -> some View {
        Button(action: { store.setSpeed(v) }) {
            Text("\(v)×")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(store.speed == v ? Color.ccAccent : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Скорость \(v)")
    }
}
