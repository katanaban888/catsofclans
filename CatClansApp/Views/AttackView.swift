import Foundation
import SwiftUI

/// Экран выбора вражеской базы для атаки.
struct AttackView: View {
    @EnvironmentObject var store: GameStore
    private let requiredLevels = [1, 2, 4, 6, 8]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { store.showAttack = false }

            VStack(spacing: 10) {
                header
                armyStatus
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { d in
                            AttackCard(difficulty: d, requiredLevel: requiredLevels[d - 1])
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
        HStack {
            PanelTitle(text: "Штурм деревни")
            Spacer()
            Button { store.showAttack = false } label: {
                Image(systemName: "xmark.circle.fill")
                .frame(width: 44, height: 44)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть атаку")
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var armyStatus: some View {
        HStack(spacing: 10) {
            if store.state.armySize == 0 {
                Text("Армия пуста — обучите котов!")
                    .font(.caption.bold()).foregroundColor(.orange)
            } else {
                ForEach(UnitTable.playerUnits, id: \.self) { unit in
                    let count = store.state.armyCount(unit)
                    if count > 0 {
                        HStack(spacing: 2) {
                            UnitSpriteView(unit: unit, size: 22)
                            Text("×\(count)").font(.caption.bold()).foregroundColor(.white)
                        }
                    }
                }
            }
            Spacer()
            if !store.state.attackReady {
                Label(
                    "Передышка \(fmtTime(store.state.attackCooldownUntil - store.state.gameTime))",
                    systemImage: "hourglass"
                )
                .font(.caption.bold())
                .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Карточка вражеской базы с мини-превью карты.
struct AttackCard: View {
    @EnvironmentObject var store: GameStore
    let difficulty: Int
    let requiredLevel: Int

    var body: some View {
        let village = VillageAssault.make(difficulty: difficulty, seed: store.state.seed)
        let enemy = village.enemy
        let locked = store.state.playerLevel < requiredLevel
        let canAttack = !locked && store.state.attackReady && store.state.armySize > 0

        VStack(spacing: 6) {
            EnemyBasePreview(village: village, seed: store.state.seed, size: 80)
                .opacity(locked ? 0.45 : 1)
            Text(enemy.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(String(repeating: "⭐", count: difficulty))
                .font(.system(size: 10))
            HStack(spacing: 6) {
                Text("🎁 \(enemy.loot.display)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            if locked {
                Label("Игрок \(requiredLevel) ур.", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            } else {
                GameCapsuleButton(title: "Штурм", icon: "flame.fill", color: canAttack ? .ccBad : .gray, enabled: canAttack) {
                    store.launchAttack(difficulty: difficulty)
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
                        .stroke(canAttack ? Color.ccBad.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 2)
                )
        )
        .accessibilityLabel("\(enemy.name), сложность \(difficulty)")
    }
}

/// Preview uses exactly the same targets, defenders and seed as the actual assault.
struct EnemyBasePreview: View {
    let village: VillageAssault
    let seed: UInt64
    var size: CGFloat

    private var simulation: BattleSim {
        BattleSim(playerUnits: [], playerStructures: [], enemy: village.enemy,
                  mode: .attack, seed: seed, villageBuildings: village.buildings)
    }

    var body: some View {
        let sim = simulation
        return ZStack(alignment: .topLeading) {
            VillageBattleScenery()
            ForEach(sim.structures) { building in
                BuildingSpriteView(type: building.type, size: building.isCore ? 86 : 66)
                    .position(x: CGFloat(building.pos.x * 20), y: CGFloat(building.pos.y * 20))
            }
            ForEach(sim.units) { unit in
                UnitSpriteView(unit: unit.stats.id, size: 32, team: .enemy)
                    .position(x: CGFloat(unit.pos.x * 20), y: CGFloat(unit.pos.y * 20))
            }
        }
        .frame(width: 800, height: 800)
        .scaleEffect(size / 650, anchor: .topLeading)
        .offset(x: -size * 75 / 650, y: -size * 30 / 650)
        .frame(width: size, height: size, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Деревня \(village.enemy.name): дом, хозяйство, заборы и кошачий гарнизон")
    }
}
