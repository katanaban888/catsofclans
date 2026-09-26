import SwiftUI

/// Thin safe-area resource strip without independent heavy badge backgrounds.
struct GameHUD: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            BuildingSpriteView(type: .home, level: store.state.homeLevel, size: 24)
            Text("Дом \(store.state.homeLevel) · Игрок \(store.state.playerLevel)")
                .font(.system(size: 11, weight: .semibold)).lineLimit(1)
                .accessibilityLabel("Дом уровня \(store.state.homeLevel), игрок уровня \(store.state.playerLevel)")
            Spacer(minLength: 0)
            ResourceHUD(resources: store.state.resources)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(Color.black.opacity(0.25))
    }
}
