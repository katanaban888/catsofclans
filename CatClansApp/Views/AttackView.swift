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
            .padding(.vertical, 12)
            .frame(maxWidth: 900)
            .background(WoodPanel(corner: 20))
            .padding(.horizontal, 20)
        }
    }

    private var header: some View {
        HStack {
            PanelTitle(text: "⚔️ Выбор цели")
            Spacer()
            Button { store.showAttack = false } label: {
                Image(systemName: "xmark.circle.fill")
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
            let roster = UnitTable.playerUnits.compactMap { u -> String? in
                let n = store.state.armyCount(u)
                return n > 0 ? "\(u.emoji)×\(n)" : nil
            }
            if roster.isEmpty {
                Label("Армия пуста — обучите котов в Академии!", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            } else {
                Text(roster.joined(separator: "  "))
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.9))
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
        let enemy = EnemyGenerator.base(difficulty: difficulty, seed: store.state.seed)
        let locked = store.state.playerLevel < requiredLevel
        let canAttack = !locked && store.state.attackReady && store.state.armySize > 0

        VStack(spacing: 6) {
            EnemyBasePreview(enemy: enemy, size: 110)
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
                GameCapsuleButton(title: "Атаковать", icon: "flame.fill", color: canAttack ? .ccBad : .gray, enabled: canAttack) {
                    store.launchAttack(difficulty: difficulty)
                }
            }
        }
        .padding(10)
        .frame(width: 160)
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

/// Миниатюра вражеской базы: ядро, башни и защитники на траве.
struct EnemyBasePreview: View {
    let enemy: EnemyBase
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: [Color.ccTileA, Color.ccTileB], startPoint: .top, endPoint: .bottom)
                )
            GeometryReader { g in
                let s = min(g.size.width, g.size.height)
                let c = CGPoint(x: g.size.width / 2, y: g.size.height * 0.42)
                ZStack {
                    // Ядро.
                    Text(enemy.coreEmoji)
                        .font(.system(size: s * 0.24))
                        .position(c)
                    // Башни по кольцу.
                    ForEach(Array(enemy.towers.enumerated()), id: \.offset) { i, t in
                        let angle = 2 * Double.pi * Double(i) / Double(max(1, enemy.towers.count)) + 0.6
                        let r = s * 0.30
                        BuildingSpriteView(type: t.type, level: t.level, size: s * 0.22)
                            .position(
                                x: c.x + CGFloat(Foundation.cos(angle) * r),
                                y: c.y + CGFloat(Foundation.sin(angle) * r)
                            )
                    }
                    // Защитники.
                    ForEach(Array(enemy.defenders.enumerated()), id: \.offset) { i, d in
                        let angle = 2 * Double.pi * Double(i) / Double(max(1, enemy.defenders.count)) + 2.2
                        let r = s * 0.36
                        UnitSpriteView(unit: d.unit, size: s * 0.18)
                            .position(
                                x: c.x + CGFloat(Foundation.cos(angle) * r),
                                y: c.y + CGFloat(Foundation.sin(angle) * r)
                            )
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.4), lineWidth: 2))
    }
}
