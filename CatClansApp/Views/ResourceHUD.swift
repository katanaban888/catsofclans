import SwiftUI

/// Плашка с количеством одного ресурса.
struct ResourceChip: View {
    let resource: Resource
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            ResourceIcon(resource: resource, size: 18)
            Text("\(value)")
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

/// Верхняя полоса ресурсов (рыба, сметана, пряжа, мыши).
struct ResourceHUD: View {
    let resources: ResourceAmounts

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Resource.allCases) { r in
                ResourceChip(resource: r, value: resources[r])
            }
        }
    }
}
