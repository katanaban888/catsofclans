import SwiftUI

struct BuildSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Запасы: \(store.state.resources.display)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Новые постройки") {
                    ForEach(BuildingType.allCases.filter { $0 != .home }) { t in
                        BuildRow(type: t)
                    }
                }
            }
            .navigationTitle("Стройка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct BuildRow: View {
    @EnvironmentObject var store: GameStore
    let type: BuildingType

    var body: some View {
        let def = BuildingTable.def(type)
        let cost = BuildingTable.buildCost(type)
        let locked = store.state.homeLevel < def.requiredHomeLevel
        let canAfford = store.state.resources.canAfford(cost)
        HStack(spacing: 12) {
            Text(def.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(def.ruName)
                    .font(.subheadline.bold())
                if locked {
                    Text("🔒 Нужен Дом котов \(def.requiredHomeLevel) ур.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(def.flavor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    ResourceLine(amount: cost, affordable: canAfford)
                }
            }
            Spacer()
            if !locked {
                Button(action: { store.build(type) }) {
                    Text("Построить")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(canAfford ? Color.ccGood : Color.gray.opacity(0.5)))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
            }
        }
        .padding(.vertical, 4)
    }
}
