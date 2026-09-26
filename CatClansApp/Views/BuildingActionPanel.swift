import SwiftUI

/// Компактная игровая панель действий по нажатию на здание.
struct BuildingActionPanel: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let b = store.state.buildings.first(where: { $0.id == (store.selectedBuilding?.id ?? -1) }) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 0)
                panel(for: b)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(Color.clear.contentShape(Rectangle()).onTapGesture { close() })
        }
    }

    private func close() {
        store.selectedBuilding = nil
    }

    private func panel(for b: PlacedBuilding) -> some View {
        let def = BuildingTable.def(b.type)
        let isHome = b.type == .home
        let atMax = b.level >= def.maxLevel
        let cost = BuildingTable.upgradeCost(b.type, toLevel: b.level + 1)
        let affordable = store.state.resources.canAfford(cost)

        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                BuildingSpriteView(type: b.type, level: b.level, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.ruName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(def.flavor)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    statChips(for: b, def: def, isHome: isHome)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть")
            }

            HStack(spacing: 10) {
                ResourceLine(amount: atMax ? .zero : cost, affordable: affordable)
                Spacer()
                if atMax {
                    Text("Макс. уровень")
                        .font(.subheadline.bold())
                        .foregroundColor(.ccAccent)
                } else {
                    GameCapsuleButton(
                        title: "Улучшить → \(b.level + 1)",
                        icon: "arrow.up",
                        color: affordable ? .ccGood : .gray,
                        enabled: affordable
                    ) {
                        store.upgrade(slot: b.slot)
                    }
                }
            }
        }
        .padding(14)
        .background(WoodPanel(corner: 18))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }

    private func statChips(for b: PlacedBuilding, def: BuildingDef, isHome: Bool) -> some View {
        HStack(spacing: 6) {
            chip("ур. \(b.level)/\(def.maxLevel)")
            if isHome {
                chip("HP \(Int(store.state.homeHP))/\(store.state.homeMaxHP)")
            } else {
                chip("HP \(BuildingTable.maxHP(b.type, level: b.level))")
            }
            if def.isTower {
                chip("урон \(BuildingTable.towerDamage(b.type, level: b.level))")
            }
            let prod = BuildingTable.production(b.type, level: b.level)
            ForEach(Resource.allCases) { r in
                if let v = prod[r], v > 0 {
                    chip("+\(Int(v)) \(r.emoji)/мин")
                }
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold).monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.45)))
    }
}
