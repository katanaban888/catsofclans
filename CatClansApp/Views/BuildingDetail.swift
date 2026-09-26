import Foundation
import SwiftUI

struct BuildingDetailView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let building: PlacedBuilding

    var body: some View {
        NavigationView {
            // Всегда читаем «живое» состояние (уровень мог измениться).
            let live = store.state.buildings.first { $0.id == building.id } ?? building
            let def = BuildingTable.def(live.type)
            let canUpgrade = live.level < def.maxLevel
            let cost = canUpgrade
                ? BuildingTable.upgradeCost(live.type, toLevel: live.level + 1)
                : ResourceAmounts.zero
            let affordable = store.state.resources.canAfford(cost)

            ScrollView {
                VStack(spacing: 16) {
                    Text(def.emoji)
                        .font(.system(size: 64))
                    Text(def.ruName)
                        .font(.title2.bold())
                    Text(def.flavor)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Характеристики.
                    VStack(alignment: .leading, spacing: 8) {
                        statRow("Уровень", "\(live.level)/\(def.maxLevel)")
                        if live.type == .home {
                            statRow(
                                "HP дома",
                                "\(Int(store.state.homeHP))/\(store.state.homeMaxHP)"
                            )
                        }
                        let prod = BuildingTable.production(live.type, level: live.level)
                        for r in Resource.allCases {
                            if let v = prod[r], v > 0 {
                                statRow(r.ruName, "+\(Int(v))/мин")
                            }
                        }
                        if def.isTower {
                            statRow("Урон", "\(BuildingTable.towerDamage(live.type, level: live.level))")
                            statRow("Дальность", String(format: "%.1f", def.towerRange))
                        }
                        if live.type == .trap {
                            statRow("Оглушение", String(format: "%.1f с", def.trapStun))
                            statRow("Радиус", String(format: "%.1f", def.trapRadius))
                        }
                        if live.type == .academy {
                            statRow("Вместимость армии", "\(store.state.armyCapacity)")
                        }
                        if live.type == .workshop {
                            statRow("Бонус армии", "+\(Int(12 * (live.level - 1)))% HP/урон")
                            statRow("Скорость обучения", "+\(Int(5 * (live.level - 1)))%")
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ccCard))

                    if canUpgrade {
                        VStack(spacing: 8) {
                            Text("Улучшить до \(live.level + 1) ур.")
                                .font(.subheadline.bold())
                            ResourceLine(amount: cost, affordable: affordable)
                            Button(action: { store.upgrade(slot: live.slot) }) {
                                Text("Улучшить")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(affordable ? Color.ccGood : Color.gray.opacity(0.4))
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!affordable)
                        }
                    } else {
                        Text("✨ Максимальный уровень")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(def.ruName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospacedDigit())
        }
    }
}
