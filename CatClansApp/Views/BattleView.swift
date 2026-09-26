import SwiftUI

// MARK: - Экран боя (поверх деревни)

struct BattleScreen: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / CGFloat(BattleSim.mapSize)
            ZStack {
                Color(red: 0.10, green: 0.14, blue: 0.10)
                if let b = store.battle {
                    // Строения.
                    ForEach(b.structures) { st in
                        BattleStructureView(snap: st)
                            .position(x: st.x * s, y: st.y * s)
                    }
                    // Юниты.
                    ForEach(b.units) { u in
                        BattleUnitView(snap: u)
                            .position(x: u.x * s, y: u.y * s)
                    }
                }
            }
        }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { eventFeed }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(store.battleTitle)
                    .font(.subheadline.bold())
                Spacer()
                if let b = store.battle {
                    let left = b.limit - b.time
                    Text(fmtTime(left))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(left < 10 ? .red : .white)
                }
            }
            HStack(spacing: 10) {
                Button(action: { store.togglePause() }) {
                    Image(systemName: store.paused ? "play.fill" : "pause.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                ForEach([1, 2, 4], id: \.self) { m in
                    Button("\(m)×") { store.setSpeed(m) }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                store.speed == m && !store.paused
                                    ? Color.ccAccent
                                    : Color.white.opacity(0.15)
                            )
                        )
                }
                if store.battleMode == .attack {
                    Button("Отступить") { store.surrender() }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55))
    }

    private var eventFeed: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let b = store.battle {
                ForEach(b.events) { e in
                    let age = max(0, b.time - e.t)
                    Text("\(fmtClock(e.t))  \(e.text)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .opacity(age > 5 ? 0.3 : 1)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Спрайты

struct BattleStructureView: View {
    let snap: StructSnap

    var body: some View {
        VStack(spacing: 2) {
            Text(snap.emoji)
                .font(.system(size: snap.isCore ? 30 : 22))
                .opacity(snap.destroyed ? 0.25 : 1)
            if !snap.destroyed {
                HPBar(
                    frac: Double(snap.hp) / Double(max(1, snap.maxHP)),
                    width: 30
                )
            }
        }
        .padding(3)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    snap.team == .enemy ? Color.red.opacity(0.65) : Color.blue.opacity(0.65),
                    lineWidth: 1.5
                )
        )
    }
}

struct BattleUnitView: View {
    let snap: UnitSnap

    var body: some View {
        VStack(spacing: 1) {
            Text(snap.emoji)
                .font(.system(size: 16))
            HPBar(
                frac: Double(snap.hp) / Double(max(1, snap.maxHP)),
                width: 18
            )
        }
        .overlay(alignment: .topTrailing) {
            if snap.stunned {
                Text("💫")
                    .font(.system(size: 10))
            }
        }
        .overlay(
            Circle()
                .stroke(
                    snap.team == .enemy ? Color.red.opacity(0.4) : Color.blue.opacity(0.4),
                    lineWidth: 1
                )
                .frame(width: 24, height: 24)
        )
    }
}
