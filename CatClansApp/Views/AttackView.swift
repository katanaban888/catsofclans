import SwiftUI

struct AttackView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private let requiredLevels = [1, 2, 4, 6, 8]

    var body: some View {
        NavigationView {
            List {
                Section("Ваша армия") {
                    let roster = UnitTable.playerUnits.compactMap { u -> String? in
                        let n = store.state.armyCount(u)
                        return n > 0 ? "\(u.emoji)×\(n)" : nil
                    }
                    if roster.isEmpty {
                        Text("Пока никого. Загляните в Академию! 🎓")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(roster.joined(separator: "  "))
                            .font(.caption)
                    }
                    if !store.state.attackReady {
                        Text("⏳ Передышка: ещё \(fmtTime(store.state.attackCooldownUntil - store.state.gameTime))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Section("Вражеские базы") {
                    ForEach(1...5, id: \.self) { d in
                        AttackRow(difficulty: d, requiredLevel: requiredLevels[d - 1])
                    }
                }
            }
            .navigationTitle("Атака")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct AttackRow: View {
    @EnvironmentObject var store: GameStore
    let difficulty: Int
    let requiredLevel: Int

    var body: some View {
        let enemy = EnemyGenerator.base(difficulty: difficulty, seed: store.state.seed)
        let locked = store.state.playerLevel < requiredLevel
        let canAttack = !locked && store.state.attackReady && store.state.armySize > 0

        let defSummary = enemy.defenders
            .map { "\($0.unit.emoji)×\($0.count)" }
            .joined(separator: " ")
        let towerSummary = enemy.towers
            .map { BuildingTable.def($0.type).emoji }
            .joined(separator: " ")

        HStack(spacing: 12) {
            Text(enemy.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(enemy.name)
                        .font(.subheadline.bold())
                    Text("сложность \(difficulty)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("\(defSummary) \(towerSummary)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Text("🎁 \(enemy.loot.display)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("⭐ +\(enemy.xp)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if locked {
                    Text("🔒 Нужен уровень игрока \(requiredLevel)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            Button(action: { store.launchAttack(difficulty: difficulty) }) {
                Text("Атаковать")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(canAttack ? Color.ccBad : Color.gray.opacity(0.5)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canAttack)
        }
        .padding(.vertical, 4)
    }
}
