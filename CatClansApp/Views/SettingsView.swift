import SwiftUI

/// Экран настроек.
struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @AppStorage("cc.sound") private var soundOn = true
    @AppStorage("cc.notifications") private var notifOn = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { store.showSettings = false }

            VStack(spacing: 14) {
                HStack {
                    PanelTitle(text: "⚙️ Настройки")
                    Spacer()
                    Button { store.showSettings = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Закрыть настройки")
                }

                toggleRow("Звук", systemIcon: "speaker.wave.2.fill", isOn: $soundOn)
                toggleRow("Уведомления", systemIcon: "bell.fill", isOn: $notifOn)

                infoRow("Версия деревни", "ур. \(store.state.homeLevel)")
                infoRow("Уровень игрока", "\(store.state.playerLevel)")

                HStack {
                    Spacer()
                    GameCapsuleButton(title: "Сбросить прогресс", icon: "trash.fill", color: .ccBad) {
                        store.showSettings = false
                        store.showResetConfirm = true
                    }
                    Spacer()
                }
                .padding(.top, 4)

                Text("КотоКланы · оригинальная стратегия про котов")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(WoodPanel(corner: 20))
            .padding(24)
        }
    }

    private func toggleRow(_ title: String, systemIcon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: systemIcon).foregroundColor(.ccAccent)
            Text(title).foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.ccGood)
                .frame(width: 50)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
    }
}
