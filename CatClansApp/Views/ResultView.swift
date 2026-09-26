import SwiftUI

/// Полноэкранный итог боя.
struct ResultView: View {
    @EnvironmentObject var store: GameStore
    let payload: ResultPayload

    var body: some View {
        let r = payload.result
        let isAttack = payload.mode == .attack

        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(bannerText)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(r.victory ? .ccGood : .ccBad)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 2)
                Text(payload.enemyName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    ResultStat(icon: "⏱", label: "Время", value: fmtTime(r.duration))
                    ResultStat(icon: "💥", label: "Стройки", value: "\(r.destroyedStructures)/\(r.totalStructures)")
                    ResultStat(icon: "⭐", label: "Опыт", value: "+\(r.xp)")
                }

                lootBox(isAttack: isAttack)

                if !isAttack && r.coreDamageFrac > 0.01 {
                    Text("Дом получил \(Int(r.coreDamageFrac * 100))% урона — он будет постепенно чиниться.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                GameCapsuleButton(title: "В деревню", icon: "house.fill", color: .ccAccent) {
                    store.result = nil
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(WoodPanel(corner: 22))
            .padding(24)
        }
    }

    private var bannerText: String {
        let isAttack = payload.mode == .attack
        if payload.result.victory {
            return isAttack ? "🎉 ПОБЕДА!" : "🛡️ РЕЙД ОТБИТ!"
        }
        return isAttack ? "💔 Поражение" : "🐾 Грабители ушли"
    }

    @ViewBuilder
    private func lootBox(isAttack: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isAttack ? "Добыча" : "Награда")
                .font(.headline)
                .foregroundColor(.white)
            if payload.result.loot == ResourceAmounts.zero {
                Text("Пусто…")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(Resource.allCases) { res in
                    if payload.result.loot[res] > 0 {
                        HStack(spacing: 8) {
                            ResourceIcon(resource: res, size: 20)
                            Text(res.ruName).foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Text("+\(payload.result.loot[res])")
                                .bold()
                                .foregroundColor(.ccGood)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35)))
    }
}

struct ResultStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.title3)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
    }
}
