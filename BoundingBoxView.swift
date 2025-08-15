import SwiftUI
struct BoundingBoxView: View {
    let boxes: [CGRect]
    let labels: [String]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ForEach(boxes.indices, id: \.self) { index in
                drawBox(
                    boxes[index],
                    label: labels[safe: index] ?? "",
                    in: geometry.size
                )
            }
        }
    }

    @ViewBuilder
    private func drawBox(_ box: CGRect, label: String, in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(color, lineWidth: 2)
                .frame(
                    width: box.width * size.width,
                    height: box.height * size.height
                )
                .position(
                    x: box.midX * size.width,
                    y: (1 - box.midY) * size.height
                )

            Text(label)
                .font(.caption)
                .padding(2)
                .background(Color.black.opacity(0.6))
                .foregroundColor(color)
                .position(
                    x: box.midX * size.width,
                    y: (1 - box.midY) * size.height - 10
                )
        }
    }
}

