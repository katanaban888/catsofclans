import SwiftUI

/// Верхний игровой HUD: уровень дома, уровень игрока, ресурсы.
struct GameHUD: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            homeBadge
            playerBadge
            Spacer(minLength: 8)
            ResourceHUD(resources: store.state.resources)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var homeBadge: some View {
        HStack(spacing: 6) {
            BuildingSpriteView(type: .home, level: store.state.homeLevel, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Дом котов")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                Text("ур. \(store.state.homeLevel)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.ccAccent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().stroke(Color.ccAccent.opacity(0.5), lineWidth: 1))
        .accessibilityLabel("Дом котов уровня \(store.state.homeLevel)")
    }

    private var playerBadge: some View {
        let xp = store.state.xpProgress
        return VStack(alignment: .leading, spacing: 2) {
            Text("Игрок ур. \(store.state.playerLevel)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.5))
                    Capsule()
                        .fill(Color.ccAccent)
                        .frame(width: max(0, min(1, Double(xp.current) / Double(max(1, xp.needed)))) * g.size.width)
                }
            }
            .frame(width: 90, height: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .accessibilityLabel("Уровень игрока \(store.state.playerLevel)")
    }
}
