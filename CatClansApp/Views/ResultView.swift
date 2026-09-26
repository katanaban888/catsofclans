import SwiftUI

struct ResultView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let payload: ResultPayload

    var body: some View {
        NavigationView {
            let r = payload.result
            let isAttack = payload.mode == .attack
            ScrollView {
                VStack(spacing: 18) {
                    Text(bannerText)
                        .font(.largeTitle.bold())
                    Text(payload.enemyName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ResultStat(icon: "⏱", label: "Время", value: fmtTime(r.duration))
                        ResultStat(
                            icon: "💥",
                            label: "Стройки",
                            value: "\(r.destroyedStructures)/\(r.totalStructures)"
                        )
                        ResultStat(icon: "⭐", label: "Опыт", value: "+\(r.xp)")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(isAttack ? "Добыча" : "Награда")
                            .font(.headline)
                        let empty = r.loot == ResourceAmounts.zero
                        if empty {
                            Text("Пусто…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Resource.allCases) { res in
                                if r.loot[res] > 0 {
                                    HStack {
                                        Text(res.emoji)
                                        Text(res.ruName)
                                        Spacer()
                                        Text("+\(r.loot[res])")
                                            .bold()
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ccCard))

                    if !isAttack && r.coreDamageFrac > 0.01 {
                        Text("Дом получил \(Int(r.coreDamageFrac * 100))% урона — он будет постепенно чиниться.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { dismiss() }) {
                        Text("В деревню")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.ccAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Итог")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var bannerText: String {
        let isAttack = payload.mode == .attack
        if payload.result.victory {
            return isAttack ? "🎉 ПОБЕДА!" : "🛡️ РЕЙД ОТБИТ!"
        }
        return isAttack ? "💔 Поражение" : "🐾 Грабители ушли"
    }
}

struct ResultStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title3)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.ccCard))
    }
}
