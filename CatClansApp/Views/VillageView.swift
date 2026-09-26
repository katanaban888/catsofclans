import SwiftUI

// MARK: - Деревня

struct VillageView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        GeometryReader { geo in
            let cw = geo.size.width / CGFloat(GameState.gridColumns)
            let ch = geo.size.height / CGFloat(GameState.gridRows)
            ZStack(alignment: .topLeading) {
                // Газон.
                ForEach(0..<GameState.slotCount, id: \.self) { slot in
                    let r = GameState.slotRow(slot)
                    let c = GameState.slotColumn(slot)
                    RoundedRectangle(cornerRadius: 6)
                        .fill((r + c) % 2 == 0 ? Color.ccTileA : Color.ccTileB)
                        .frame(width: cw - 4, height: ch - 4)
                        .position(x: (CGFloat(c) + 0.5) * cw, y: (CGFloat(r) + 0.5) * ch)
                }
                // Здания.
                ForEach(store.state.buildings) { b in
                    let c = GameState.slotColumn(b.slot)
                    let r = GameState.slotRow(b.slot)
                    BuildingTile(
                        building: b,
                        homeHP: store.state.homeHP,
                        homeMax: store.state.homeMaxHP
                    )
                    .frame(width: cw - 8, height: ch - 8)
                    .position(x: (CGFloat(c) + 0.5) * cw, y: (CGFloat(r) + 0.5) * ch)
                    .onTapGesture {
                        store.selectedBuilding = b
                    }
                }
            }
        }
        .padding(8)
    }
}

struct BuildingTile: View {
    let building: PlacedBuilding
    let homeHP: Double
    let homeMax: Int

    var body: some View {
        let def = BuildingTable.def(building.type)
        let homeDamaged = building.type == .home && homeHP < Double(homeMax)
        VStack(spacing: 2) {
            Text(def.emoji)
                .font(.system(size: 24))
            Text(def.ruName)
                .font(.system(size: 8))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(.white)
            Text("ур.\(building.level)")
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .foregroundColor(.white)
            if homeDamaged {
                HPBar(frac: homeHP / Double(max(1, homeMax)), width: 42)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(building.type == .home ? Color.orange.opacity(0.16) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    building.type == .home ? Color.orange.opacity(0.6) : Color.white.opacity(0.15),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Оффлайн-подсказка

struct OfflineSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("😴")
                    .font(.system(size: 60))
                Text("Пока вас не было (\(fmtDuration(store.offline?.elapsed ?? 0)))")
                    .font(.headline)
                Text(store.offline?.note ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: { dismiss() }) {
                    Text("Мурр!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.ccAccent))
                }
                .padding(.top, 8)
            }
            .padding()
            .navigationTitle("Возвращение")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
