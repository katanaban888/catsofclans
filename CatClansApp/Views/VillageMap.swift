import SwiftUI
import UIKit

/// Декоративный элемент карты.
private struct DecorItem: Identifiable {
    let id: Int
    let asset: String
    let fallback: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let flip: Bool
}

/// Большая игровая карта деревни: трава, тайлы, декор, здания, границы.
struct VillageMap: View {
    @EnvironmentObject var store: GameStore

    // Дизайн-размеры карты.
    private let cell: CGFloat = 88
    private let margin: CGFloat = 76

    private var gridW: CGFloat { cell * CGFloat(GameState.gridColumns) }
    private var gridH: CGFloat { cell * CGFloat(GameState.gridRows) }
    private var contentW: CGFloat { gridW + margin * 2 }
    private var contentH: CGFloat { gridH + margin * 2 }

    var body: some View {
        MapViewport(worldSize: V2(Double(contentW), Double(contentH)),
                    home: homePosition,
                    onTap: select) {
            mapContent
        }
    }

    private var homePosition: V2 {
        let slot = store.state.buildings.first { $0.type == .home }?.slot ?? GameState.homeSlot
        let point = slotCenter(c: GameState.slotColumn(slot), r: GameState.slotRow(slot))
        return V2(Double(point.x), Double(point.y))
    }

    private func select(_ point: V2) {
        let col = Int(floor((point.x - Double(margin)) / Double(cell)))
        let row = Int(floor((point.y - Double(margin)) / Double(cell)))
        guard (0..<GameState.gridColumns).contains(col), (0..<GameState.gridRows).contains(row) else { return }
        let slot = row * GameState.gridColumns + col
        if store.placingBuilding != nil {
            guard !usedSlots.contains(slot) else { store.showToast("Участок занят"); return }
            store.placementSlot = slot
        } else {
            store.selectedBuilding = store.state.buildings.first { $0.slot == slot }
        }
    }

    private var mapContent: some View {
        ZStack(alignment: .topLeading) {
            terrain
            decorLayer
            paths
            if store.placingBuilding != nil { emptySlotLayer }
            buildingLayer
            placementPreview
        }
    }

    // MARK: Слой травы

    private var terrain: some View {
        ZStack {
            if UIImage(named: "map_bg") != nil {
                Image("map_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: contentW, height: contentH)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.ccGrassA, Color.ccGrassB],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            // Лёгкая фактура травы.
            Canvas { ctx, size in
                var rng = SeededRNG(seed: 7)
                for _ in 0..<220 {
                    let x = rng.double(0, Double(size.width))
                    let y = rng.double(0, Double(size.height))
                    let r = rng.double(1, 2.4)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05)))
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: Декор по краям

    private var decorItems: [DecorItem] {
        var rng = SeededRNG(seed: 42)
        var items: [DecorItem] = []
        let kinds: [(String, String)] = [
            ("d_tree", "🌳"), ("d_bush", "🌿"), ("d_rock", "🪨"), ("d_flower", "🌸"),
        ]
        for i in 0..<48 {
            let k = kinds[rng.nextInt(kinds.count)]
            let side = rng.nextInt(4)
            var x: CGFloat = 0
            var y: CGFloat = 0
            let along = CGFloat(rng.double(0, 1))
            switch side {
            case 0: // верх
                x = along * contentW
                y = CGFloat(rng.double(8, Double(margin) - 30))
            case 1: // низ
                x = along * contentW
                y = contentH - CGFloat(rng.double(8, Double(margin) - 30))
            case 2: // лево
                x = CGFloat(rng.double(8, Double(margin) - 30))
                y = along * contentH
            default: // право
                x = contentW - CGFloat(rng.double(8, Double(margin) - 30))
                y = along * contentH
            }
            items.append(DecorItem(
                id: i,
                asset: k.0,
                fallback: k.1,
                x: x,
                y: y,
                size: CGFloat(rng.double(26, 52)),
                flip: rng.chance(0.5)
            ))
        }
        return items
    }

    private var decorLayer: some View {
        ForEach(decorItems) { d in
            SpriteView(asset: d.asset, fallbackEmoji: d.fallback, size: d.size)
                .scaleEffect(x: d.flip ? -1 : 1, y: 1)
                .position(x: d.x, y: d.y)
                .allowsHitTesting(false)
        }
    }

    private var paths: some View {
        Path { p in
            p.move(to: CGPoint(x: contentW / 2, y: margin))
            p.addLine(to: CGPoint(x: contentW / 2, y: contentH - margin))
            p.move(to: CGPoint(x: margin, y: contentH / 2))
            p.addLine(to: CGPoint(x: contentW - margin, y: contentH / 2))
        }
        .stroke(Color(red: 0.7, green: 0.61, blue: 0.37).opacity(0.5),
                style: StrokeStyle(lineWidth: 20, lineCap: .round))
        .allowsHitTesting(false)
    }

    private var usedSlots: Set<Int> { Set(store.state.buildings.map { $0.slot }) }

    private var emptySlotLayer: some View {
        ForEach(0..<GameState.slotCount, id: \.self) { slot in
            if !usedSlots.contains(slot) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                    .frame(width: cell - 12, height: cell - 12)
                    .position(slotCenter(c: GameState.slotColumn(slot), r: GameState.slotRow(slot)))
                    .accessibilityElement()
                    .accessibilityLabel("Свободный участок \(slot + 1)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.placementSlot = slot }
            }
        }
    }

    @ViewBuilder private var placementPreview: some View {
        if let type = store.placingBuilding, let slot = store.placementSlot {
            BuildingSpriteView(type: type, size: 68)
                .opacity(0.55)
                .position(slotCenter(c: GameState.slotColumn(slot), r: GameState.slotRow(slot)))
                .allowsHitTesting(false)
        }
    }

    // MARK: Здания

    private var buildingLayer: some View {
        ForEach(store.state.buildings) { b in
            let c = GameState.slotColumn(b.slot)
            let r = GameState.slotRow(b.slot)
            MapBuilding(building: b, homeHP: store.state.homeHP, homeMax: store.state.homeMaxHP)
                .background(Ellipse().fill(store.selectedBuilding?.id == b.id ? Color.ccAccent.opacity(0.25) : .clear))
                .position(slotCenter(c: c, r: r))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { store.selectedBuilding = b }
        }
    }

    private func slotCenter(c: Int, r: Int) -> CGPoint {
        CGPoint(
            x: margin + (CGFloat(c) + 0.5) * cell,
            y: margin + (CGFloat(r) + 0.5) * cell
        )
    }
}

/// Здание на карте с именем, уровнем и HP дома.
private struct MapBuilding: View {
    let building: PlacedBuilding
    let homeHP: Double
    let homeMax: Int

    var body: some View {
        let def = BuildingTable.def(building.type)
        let isHome = building.type == .home
        let size: CGFloat = isHome ? 68 : 60
        VStack(spacing: 2) {
            BuildingSpriteView(type: building.type, level: building.level, size: size)
                .scaleEffect(isHome ? 1.12 : 1.0)
            Text("ур.\(building.level)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.black.opacity(0.55)))
            if isHome && homeHP < Double(homeMax) {
                HPBar(frac: homeHP / Double(max(1, homeMax)), width: 52)
            }
        }
        .frame(width: 82, height: 86)
        .contentShape(Rectangle())
        .accessibilityLabel("\(def.ruName), уровень \(building.level)")
    }
}
