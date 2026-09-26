import SwiftUI

/// Non-target scenery only. All buildings are real simulation structures with HP bars.
/// Same layer is used in the full battle and miniature. No RNG or resource rewards.
struct VillageBattleScenery: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("map_bg").resizable().scaledToFill().frame(width: 800, height: 800).clipped()
            paths
            ForEach(0..<16, id: \.self) { index in
                SpriteView(asset: index % 3 == 0 ? "d_tree" : "d_bush", fallbackEmoji: "", size: 52)
                    .position(x: CGFloat(index % 2 == 0 ? 65 : 735),
                              y: CGFloat(70 + (index / 2) * 90))
            }
            ForEach(0..<8, id: \.self) { index in
                SpriteView(asset: index % 2 == 0 ? "d_flower" : "d_rock", fallbackEmoji: "", size: 22)
                    .position(x: CGFloat(240 + (index % 4) * 105),
                              y: CGFloat(index < 4 ? 95 : 560))
            }
            // Small courtyard stepping stones, clearly unlike selectable buildings.
            ForEach(0..<7, id: \.self) { index in
                Ellipse().fill(Color.white.opacity(0.18))
                    .frame(width: 14, height: 9)
                    .position(x: CGFloat(386 + index % 2 * 28), y: CGFloat(380 + index * 34))
            }
        }
        .frame(width: 800, height: 800)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var paths: some View {
        Path { path in
            path.move(to: CGPoint(x: 400, y: 740))
            path.addLine(to: CGPoint(x: 400, y: 170))
            path.move(to: CGPoint(x: 170, y: 350))
            path.addQuadCurve(to: CGPoint(x: 630, y: 350), control: CGPoint(x: 400, y: 420))
            path.move(to: CGPoint(x: 200, y: 200))
            path.addQuadCurve(to: CGPoint(x: 600, y: 200), control: CGPoint(x: 400, y: 320))
        }
        .stroke(Color(red: 0.68, green: 0.56, blue: 0.34).opacity(0.65),
                style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
    }
}
