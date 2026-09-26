import SwiftUI

/// Игровой экран армии.
struct ArmyPanel: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { store.showArmy = false }

            VStack(spacing: 10) {
                header
                queueRow
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(UnitTable.playerUnits, id: \.self) { u in
                            ArmyCard(unit: u)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: 540)
            .background(WoodPanel(corner: 20))
            .padding(.horizontal, 20)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            PanelTitle(text: "🎓 Академия котов")
            Spacer()
            capacityBadge
            closeBtn
        }
        .padding(.horizontal, 16)
    }

    private var capacityBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill").foregroundColor(.ccGood)
            Text("\(store.state.armySize)/\(store.state.armyCapacity)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .accessibilityLabel("Вместимость армии \(store.state.armySize) из \(store.state.armyCapacity)")
    }

    private var closeBtn: some View {
        Button { store.showArmy = false } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Закрыть армию")
    }

    @ViewBuilder
    private var queueRow: some View {
        if !store.state.queue.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(store.state.queue.enumerated()), id: \.offset) { _, job in
                    HStack(spacing: 6) {
                        UnitSpriteView(unit: job.unit, size: 26)
                        ProgressView(value: job.progress)
                            .tint(Color.ccAccent)
                            .frame(width: 70)
                        Text(fmtTime(job.remaining))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Карточка бойца.
struct ArmyCard: View {
    @EnvironmentObject var store: GameStore
    let unit: UnitID

    var body: some View {
        let def = UnitTable.def(unit)
        let owned = store.state.armyCount(unit)
        let queueCount = store.state.queue.filter { $0.unit == unit }.count
        let lockedHome = store.state.homeLevel < def.requiredHomeLevel
        let lockedAcademy = store.state.academyLevel < def.requiredAcademyLevel
        let full = store.state.armySize + store.state.queue.count >= store.state.armyCapacity
        let affordable = store.state.resources.canAfford(def.trainingCost)
        let canTrain = !lockedHome && !lockedAcademy && !full && affordable
        let locked = lockedHome || lockedAcademy

        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                UnitSpriteView(unit: unit, size: 48)
                    .opacity(locked ? 0.4 : 1)
                if owned + queueCount > 0 {
                    Text("×\(owned + queueCount)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.ccGood))
                }
            }
            Text(unit.ruName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text("❤️\(def.baseHP) ⚔️\(def.baseDamage) 🎯\(String(format: "%.1f", def.range))")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
            ResourceLine(amount: def.trainingCost, affordable: affordable)
            if locked {
                Label(
                    lockedHome ? "Дом \(def.requiredHomeLevel)" : "Академия \(def.requiredAcademyLevel)",
                    systemImage: "lock.fill"
                )
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
            } else if full {
                Text("Армия полна").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
            } else {
                GameCapsuleButton(title: "Обучить", color: canTrain ? .ccGood : .gray, enabled: canTrain) {
                    store.train(unit)
                }
            }
        }
        .padding(8)
        .frame(width: 128)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(locked ? Color.white.opacity(0.1) : Color.ccGood.opacity(0.5), lineWidth: 2)
                )
        )
        .accessibilityLabel("\(unit.ruName), обучено \(owned)")
    }
}
