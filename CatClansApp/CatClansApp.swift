import SwiftUI
import UIKit

// MARK: - Блокировка ориентации (только landscape)

/// Делегат, принудительно разрешающий только горизонтальные ориентации.
final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }
}

@main
struct CatClansApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

// MARK: - Корневой экран

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if store.battle != nil {
                BattleScreen()
                    .transition(.opacity)
            } else {
                VillageView()
                    .transition(.opacity)
            }

            if store.battle == nil {
                if store.selectedBuilding != nil {
                    BuildingActionPanel()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if store.showBuild {
                    BuildSheet()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if store.showArmy {
                    ArmyPanel()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                if store.showAttack {
                    AttackView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                if store.showSettings {
                    SettingsView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }

            if let payload = store.result {
                ResultView(payload: payload)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if store.offline != nil {
                OfflineSheet()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.battle != nil)
        .animation(.easeInOut(duration: 0.25), value: store.showBuild)
        .animation(.easeInOut(duration: 0.25), value: store.showArmy)
        .animation(.easeInOut(duration: 0.25), value: store.showAttack)
        .animation(.easeInOut(duration: 0.25), value: store.showSettings)
        .animation(.easeInOut(duration: 0.25), value: store.selectedBuilding)
        .animation(.easeInOut(duration: 0.25), value: store.result != nil)
        .animation(.easeInOut(duration: 0.2), value: store.toast)
        .alert("Сбросить прогресс?", isPresented: $store.showResetConfirm) {
            Button("Отмена", role: .cancel) {}
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
