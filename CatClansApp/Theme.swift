import Foundation
import SwiftUI
import UIKit

// MARK: - Цвета

extension Color {
    static let ccGrassA = Color(red: 0.36, green: 0.62, blue: 0.26)
    static let ccGrassB = Color(red: 0.24, green: 0.48, blue: 0.18)
    static let ccTileA = Color(red: 0.45, green: 0.70, blue: 0.30)
    static let ccTileB = Color(red: 0.40, green: 0.64, blue: 0.26)
    static let ccCard = Color.black.opacity(0.42)
    static let ccAccent = Color(red: 1.0, green: 0.65, blue: 0.20)
    static let ccGood = Color(red: 0.35, green: 0.78, blue: 0.35)
    static let ccBad = Color(red: 0.92, green: 0.32, blue: 0.26)
    static let ccWood = Color(red: 0.45, green: 0.30, blue: 0.16)
    static let ccWoodDark = Color(red: 0.30, green: 0.19, blue: 0.10)
    static let ccSky = Color(red: 0.45, green: 0.75, blue: 0.95)
}

// MARK: - Форматирование времени

/// «2:35» / «1ч 5м».
func fmtTime(_ t: TimeInterval) -> String {
    let total = max(0, Int(t.rounded()))
    let m = total / 60
    let s = total % 60
    if m >= 60 {
        return "\(m / 60)ч \(m % 60)м"
    }
    return String(format: "%d:%02d", m, s)
}

/// Как fmtTime, но без округления вверх (для ленты событий).
func fmtClock(_ t: TimeInterval) -> String {
    let total = max(0, Int(t))
    let m = total / 60
    let s = total % 60
    if m >= 60 {
        return "\(m / 60)ч \(m % 60)м"
    }
    return String(format: "%d:%02d", m, s)
}

/// «3ч 12м» / «45с».
func fmtDuration(_ t: TimeInterval) -> String {
    let total = max(0, Int(t))
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)ч \(m)м" }
    if m > 0 { return "\(m)м" }
    return "\(total % 60)с"
}

// MARK: - Мелкие переиспользуемые представления

/// Полоска HP (здоровье).
struct HPBar: View {
    let frac: Double
    var width: CGFloat = 40
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.55))
                Capsule()
                    .fill(frac > 0.5 ? Color.green : (frac > 0.25 ? Color.yellow : Color.red))
                    .frame(width: max(0, min(1, frac)) * g.size.width)
            }
        }
        .frame(width: width, height: 5)
    }
}

/// Ряд ресурсов с иконками-картинками.
struct ResourceLine: View {
    let amount: ResourceAmounts
    var affordable: Bool = true
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Resource.allCases) { r in
                if amount[r] > 0 {
                    HStack(spacing: 3) {
                        ResourceIcon(resource: r, size: 14)
                        Text("\(amount[r])")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(affordable ? .white : .red)
                    }
                }
            }
        }
    }
}

/// Всплывающее уведомление.
struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.8)))
            .padding(.top, 8)
    }
}

// MARK: - Игровые панели и кнопки

/// Деревянная «игровая» панель-подложка.
struct WoodPanel: View {
    var corner: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(
                LinearGradient(
                    colors: [Color.ccWood.opacity(0.95), Color.ccWoodDark.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

/// Круглая игровая кнопка с иконкой и подписью.
struct GameRoundButton: View {
    let title: String
    let systemIcon: String
    let artAsset: String?
    let color: Color
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(1.0), color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 2))
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                    if let artAsset = artAsset, UIImage(named: artAsset) != nil {
                        SpriteView(asset: artAsset, fallbackEmoji: "", size: size * 0.62, shadow: false)
                    } else {
                        Image(systemName: systemIcon)
                            .font(.system(size: size * 0.36, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Плоская игровая кнопка-капсула.
struct GameCapsuleButton: View {
    let title: String
    var icon: String? = nil
    let color: Color
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.subheadline.bold())
                }
                Text(title).font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(enabled ? color : Color.gray.opacity(0.5))
                    .overlay(Capsule().stroke(Color.black.opacity(0.4), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

/// Заголовок игровой панели.
struct PanelTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
    }
}
