import SwiftUI

@main
struct CatClansApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Корневой экран

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ccGrassA, Color.ccGrassB],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar()
                if store.battle != nil {
                    BattleScreen()
                } else {
                    VillageView()
                }
                if store.battle == nil {
                    BottomActionBar()
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toast)
        .sheet(item: $store.result) { payload in
            ResultView(payload: payload)
        }
        .sheet(item: $store.selectedBuilding) { b in
            BuildingDetailView(building: b)
        }
        .sheet(isPresented: $store.showBuild) { BuildSheet() }
        .sheet(isPresented: $store.showArmy) { ArmyView() }
        .sheet(isPresented: $store.showAttack) { AttackView() }
        .sheet(
            isPresented: Binding(
                get: { store.offline != nil },
                set: { if !$0 { store.offline = nil } }
            )
        ) {
            OfflineSheet()
        }
        .confirmDialog(
            "Сбросить прогресс?",
            isPresented: $store.showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Стереть деревню", role: .destructive) {
                store.resetGame()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                store.saveNow()
            }
        }
    }
}

// MARK: - Верхняя панель

struct TopBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🐾 КотоКланы")
                        .font(.headline)
                    Text("Дом ур. \(store.state.homeLevel) · игрок ур. \(store.state.playerLevel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { store.showResetConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 14) {
                ForEach(Resource.allCases) { r in
                    HStack(spacing: 3) {
                        Text(r.emoji).font(.subheadline)
                        Text("\(store.state.resources[r])")
                            .font(.subheadline.monospacedDigit().bold())
                    }
                }
                Spacer()
                let xp = store.state.xpProgress
                VStack(alignment: .trailing, spacing: 2) {
                    ProgressView(value: Double(xp.current), total: Double(max(1, xp.needed)))
                        .tint(Color.ccAccent)
                        .frame(width: 90)
                    Text("XP \(xp.current)/\(xp.needed)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

// MARK: - Нижние кнопки

struct BottomActionBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "hammer.fill", title: "Строить", color: .ccAccent) {
                store.showBuild = true
            }
            ActionButton(icon: "pawprint.fill", title: "Армия", color: Color.ccGood) {
                store.showArmy = true
            }
            ActionButton(icon: "flame.fill", title: "Атака", color: .ccBad) {
                store.showAttack = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.25))
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
    }
}
