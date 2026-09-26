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
                BottomActionBar()
            }
        }
    }
}

// MARK: - Нижняя панель действий

struct BottomActionBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 20) {
            GameRoundButton(
                title: "Магазин",
                systemIcon: "hammer.fill",
                artAsset: "btn_shop",
                color: .ccAccent,
                size: 52
            ) {
                store.showBuild = true
            }
            GameRoundButton(
                title: "Армия",
                systemIcon: "pawprint.fill",
                artAsset: "btn_army",
                color: .ccGood,
                size: 52
            ) {
                store.showArmy = true
            }
            attackButton
            GameRoundButton(
                title: "Настройки",
                systemIcon: "gearshape.fill",
                artAsset: "btn_settings",
                color: .gray,
                size: 44
            ) {
                store.showSettings = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var attackButton: some View {
        let ready = store.state.attackReady
        return GameRoundButton(
            title: ready ? "Атака" : "Отдых",
            systemIcon: "flame.fill",
            artAsset: "btn_attack",
            color: .ccBad,
            size: 60
        ) {
            store.showAttack = true
        }
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
