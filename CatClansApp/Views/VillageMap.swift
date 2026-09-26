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
    @State private var zoom: CGFloat = 1.0
    @State private var baseZoom: CGFloat = 1.0

    // Дизайн-размеры карты.
    private let cell: CGFloat = 88
    private let margin: CGFloat = 76

    private var gridW: CGFloat { cell * CGFloat(GameState.gridColumns) }
    private var gridH: CGFloat { cell * CGFloat(GameState.gridRows) }
    private var contentW: CGFloat { gridW + margin * 2 }
    private var contentH: CGFloat { gridH + margin * 2 }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    mapContent
                        .frame(width: contentW, height: contentH)
                        .scaleEffect(zoom, anchor: .topLeading)
                        .frame(width: contentW * zoom, height: contentH * zoom, alignment: .topLeading)
                        .id("village")
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .simultaneousGesture(magnify)
                .onAppear { proxy.scrollTo("village", anchor: .center) }
            }
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { v in
                zoom = min(1.6, max(0.4, baseZoom * v))
            }
            .onEnded { _ in
                baseZoom = zoom
            }
    }

    private var mapContent: some View {
        ZStack(alignment: .topLeading) {
            terrain
            decorLayer
            tileLayer
            emptySlotLayer
            buildingLayer
            villageBorder
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

    // MARK: Тайлы земли

    private var tileLayer: some View {
        ForEach(0..<GameState.slotCount, id: \.self) { slot in
            let r = GameState.slotRow(slot)
            let c = GameState.slotColumn(slot)
            RoundedRectangle(cornerRadius: 10)
                .fill((r + c) % 2 == 0 ? Color.ccTileA : Color.ccTileB)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .frame(width: cell - 6, height: cell - 6)
                .position(slotCenter(c: c, r: r))
                .allowsHitTesting(false)
        }
    }

    // MARK: Свободные участки

    private var usedSlots: Set<Int> {
        Set(store.state.buildings.map { $0.slot })
    }

    private var emptySlotLayer: some View {
        ForEach(0..<GameState.slotCount, id: \.self) { slot in
            if !usedSlots.contains(slot) {
                let r = GameState.slotRow(slot)
                let c = GameState.slotColumn(slot)
                Button {
                    store.showBuild = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            .foregroundColor(.white.opacity(0.35))
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: cell - 18, height: cell - 18)
                }
                .buttonStyle(.plain)
                .position(slotCenter(c: c, r: r))
                .accessibilityLabel("Свободный участок, построить")
            }
        }
    }

    // MARK: Здания

    private var buildingLayer: some View {
        ForEach(store.state.buildings) { b in
            let c = GameState.slotColumn(b.slot)
            let r = GameState.slotRow(b.slot)
            MapBuilding(building: b, homeHP: store.state.homeHP, homeMax: store.state.homeMaxHP)
                .position(slotCenter(c: c, r: r))
                .onTapGesture {
                    store.selectedBuilding = b
                }
        }
    }

    private var villageBorder: some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 3)
            .frame(width: gridW + 24, height: gridH + 24)
            .position(x: margin + gridW / 2, y: margin + gridH / 2)
            .allowsHitTesting(false)
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
