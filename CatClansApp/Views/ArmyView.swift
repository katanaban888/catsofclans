import Foundation
import SwiftUI

struct ArmyView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Армия: \(store.state.armySize)/\(store.state.armyCapacity)") {
                    ProgressView(
                        value: Double(store.state.armySize),
                        total: Double(max(1, store.state.armyCapacity))
                    )
                    .tint(Color.ccGood)
                    if !store.state.queue.isEmpty {
                        ForEach(Array(store.state.queue.enumerated()), id: \.offset) { _, job in
                            HStack(spacing: 10) {
                                Text(job.unit.emoji)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(job.unit.ruName)
                                        .font(.caption.bold())
                                    ProgressView(value: job.progress)
                                        .tint(Color.ccAccent)
                                }
                                Spacer()
                                Text(fmtTime(job.remaining))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section("Бойцы") {
                    ForEach(UnitTable.playerUnits, id: \.self) { u in
                        ArmyRow(unit: u)
                    }
                }
            }
            .navigationTitle("Академия котов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct ArmyRow: View {
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

        HStack(spacing: 12) {
            Text(def.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.ruName)
                        .font(.subheadline.bold())
                    if owned + queueCount > 0 {
                        Text("×\(owned + queueCount)")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
                Text("❤️ \(def.baseHP)  ⚔️ \(def.baseDamage)  🎯 \(String(format: "%.1f", def.range))  👟 \(String(format: "%.1f", def.speed))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ResourceLine(amount: def.trainingCost, affordable: affordable)
                    Text("⏱ \(fmtTime(def.trainingTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if lockedHome {
                    Text("🔒 Нужен Дом котов \(def.requiredHomeLevel) ур.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if lockedAcademy {
                    Text("🔒 Нужна Академия \(def.requiredAcademyLevel) ур.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if full {
                    Text("Армия заполнена")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            Button(action: { store.train(unit) }) {
                Text("Тренировать")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(canTrain ? Color.ccGood : Color.gray.opacity(0.5)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canTrain)
        }
        .padding(.vertical, 4)
        .opacity(lockedHome || lockedAcademy ? 0.65 : 1)
    }
}
