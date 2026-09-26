import Foundation
import SwiftUI

struct BuildingDetailView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let building: PlacedBuilding

    private var live: PlacedBuilding {
        store.state.buildings.first { $0.id == building.id } ?? building
    }

    private var definition: BuildingDef {
        BuildingTable.def(live.type)
    }

    private var canUpgrade: Bool {
        live.level < definition.maxLevel
    }

    private var upgradeCost: ResourceAmounts {
        canUpgrade
            ? BuildingTable.upgradeCost(live.type, toLevel: live.level + 1)
            : ResourceAmounts.zero
    }

    private var affordable: Bool {
        store.state.resources.canAfford(upgradeCost)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(definition.emoji)
                        .font(.system(size: 64))
                    Text(definition.ruName)
                        .font(.title2.bold())
                    Text(definition.flavor)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    statsSection

                    if canUpgrade {
                        VStack(spacing: 8) {
                            Text("Улучшить до \(live.level + 1) ур.")
                                .font(.subheadline.bold())
                            ResourceLine(amount: upgradeCost, affordable: affordable)
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
            .navigationTitle(definition.ruName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var statsSection: some View {
        let production = BuildingTable.production(live.type, level: live.level)
        let levelText = "\(live.level)/\(definition.maxLevel)"
        let homeHPText = "\(Int(store.state.homeHP))/\(store.state.homeMaxHP)"
        let towerDamageText = "\(BuildingTable.towerDamage(live.type, level: live.level))"
        let towerRangeText = String(format: "%.1f", definition.towerRange)
        let trapStunText = String(format: "%.1f с", definition.trapStun)
        let trapRadiusText = String(format: "%.1f", definition.trapRadius)
        let workshopBonus = "+\(Int(12 * (live.level - 1)))% HP/урон"
        let trainingBonus = "+\(Int(5 * (live.level - 1)))%"

        return VStack(alignment: .leading, spacing: 8) {
            statRow("Уровень", levelText)
            if live.type == .home {
                statRow("HP дома", homeHPText)
            }
            ForEach(Resource.allCases) { resource in
                if let value = production[resource], value > 0 {
                    statRow(resource.ruName, "+\(Int(value))/мин")
                }
            }
            if definition.isTower {
                statRow("Урон", towerDamageText)
                statRow("Дальность", towerRangeText)
            }
            if live.type == .trap {
                statRow("Оглушение", trapStunText)
                statRow("Радиус", trapRadiusText)
            }
            if live.type == .academy {
                statRow("Вместимость армии", "\(store.state.armyCapacity)")
            }
            if live.type == .workshop {
                statRow("Бонус армии", workshopBonus)
                statRow("Скорость обучения", trainingBonus)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ccCard))
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
