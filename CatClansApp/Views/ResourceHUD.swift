import SwiftUI

/// Плашка с количеством одного ресурса.
struct ResourceChip: View {
    let resource: Resource
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            ResourceIcon(resource: resource, size: 16)
            Text("\(value)")
                .font(.system(size: 12, weight: .heavy).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .accessibilityLabel("\(resource.ruName): \(value)")
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
