import SwiftUI

/// Игровое меню строительства (магазин).
struct BuildSheet: View {
    @EnvironmentObject var store: GameStore

    private var buildable: [BuildingType] {
        BuildingType.allCases.filter { $0 != .home }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { store.showBuild = false }

            VStack(spacing: 10) {
                HStack {
                    PanelTitle(text: "🏗️ Магазин построек")
                    Spacer()
                    closeBtn
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(buildable) { type in
                            BuildCard(type: type)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: 760)
            .background(WoodPanel(corner: 20))
            .padding(.horizontal, 20)
        }
    }

    private var closeBtn: some View {
        Button { store.showBuild = false } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Закрыть магазин")
    }
}

/// Карточка здания в магазине.
struct BuildCard: View {
    @EnvironmentObject var store: GameStore
    let type: BuildingType

    var body: some View {
        let def = BuildingTable.def(type)
        let cost = BuildingTable.buildCost(type)
        let locked = store.state.homeLevel < def.requiredHomeLevel
        let affordable = store.state.resources.canAfford(cost)
        let canBuild = !locked && affordable

        Button {
            store.build(type)
        } label: {
            VStack(spacing: 6) {
                BuildingSpriteView(type: type, level: 1, size: 64)
                    .opacity(locked ? 0.4 : 1)
                Text(def.ruName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if locked {
                    Label("Дом \(def.requiredHomeLevel) ур.", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                } else {
                    ResourceLine(amount: cost, affordable: affordable)
                }
            }
            .padding(10)
            .frame(width: 128)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(canBuild ? 0.10 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(canBuild ? Color.ccGood.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canBuild)
        .accessibilityLabel("Построить \(def.ruName)")
    }
}
