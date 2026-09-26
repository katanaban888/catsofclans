import SwiftUI

// MARK: - Деревня

struct VillageView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            // Фон на весь экран (за пределами скролла карты).
            LinearGradient(
                colors: [Color.ccGrassB, Color.ccGrassA],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUD()
                VillageMap()
                    .overlay(alignment: .bottom) {
                        if store.placingBuilding != nil {
                            PlacementBar().padding(.bottom, 12)
                        } else {
                            BottomActionBar().padding(.bottom, 12)
                        }
                    }
            }
        }
    }
}

// MARK: - Нижняя панель действий

struct BottomActionBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 4) {
            action("Магазин", asset: "btn_shop") { store.showBuild = true }
            action("Армия", asset: "btn_army") { store.showArmy = true }
            action("Штурм", asset: "btn_attack") { store.showAttack = true }
            Menu {
                Button { store.showSettings = true } label: { Label("Настройки", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 22))
                    .frame(width: 44, height: 54)
            }
            .accessibilityLabel("Ещё действия")
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }

    private func action(_ title: String, asset: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 0) {
                SpriteView(asset: asset, fallbackEmoji: "", size: 30, shadow: false)
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .frame(width: 62, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct PlacementBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            if let type = store.placingBuilding {
                BuildingSpriteView(type: type, size: 32)
                Text(store.placementSlot == nil ? "Выберите участок" : type.ruName)
                    .font(.caption).lineLimit(1)
            }
            Button("Построить") { store.confirmPlacement() }
                .frame(minWidth: 80, minHeight: 44)
                .disabled(store.placementSlot == nil)
            Button("Отмена") { store.cancelPlacement() }
                .frame(minWidth: 64, minHeight: 44)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .background(Capsule().fill(Color.black.opacity(0.7)))
        .padding(.horizontal, 8)
    }
}

// MARK: - Оффлайн-подсказка

struct OfflineSheet: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("😴")
                    .font(.system(size: 54))
                Text("Пока вас не было (\(fmtDuration(store.offline?.elapsed ?? 0)))")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(store.offline?.note ?? "")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                GameCapsuleButton(title: "Мурр!", color: .ccAccent) {
                    store.offline = nil
                }
            }
            .padding(22)
            .frame(maxWidth: 460)
            .background(WoodPanel())
            .padding(24)
        }
    }
}
