import Foundation
import SwiftUI

// MARK: - Цвета

extension Color {
    static let ccGrassA = Color(red: 0.16, green: 0.22, blue: 0.14)
    static let ccGrassB = Color(red: 0.11, green: 0.16, blue: 0.10)
    static let ccTileA = Color(red: 0.20, green: 0.28, blue: 0.18)
    static let ccTileB = Color(red: 0.18, green: 0.25, blue: 0.16)
    static let ccCard = Color.white.opacity(0.06)
    static let ccAccent = Color(red: 1.0, green: 0.65, blue: 0.20)
    static let ccGood = Color(red: 0.35, green: 0.75, blue: 0.35)
    static let ccBad = Color(red: 0.90, green: 0.35, blue: 0.30)
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

/// Ряд ресурсов «🐟 220 🥛 120».
struct ResourceLine: View {
    let amount: ResourceAmounts
    var affordable: Bool = true
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Resource.allCases) { r in
                if amount[r] > 0 {
                    Text("\(r.emoji) \(amount[r])")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(affordable ? .primary : .red)
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
