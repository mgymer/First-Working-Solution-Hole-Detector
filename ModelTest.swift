import SwiftUI

struct ModelTest: View {
    @StateObject private var viewModel = DetectionViewModel()

    var body: some View {
        VStack {
            if let testImage = UIImage(named: "test_sample") {
                Image(uiImage: testImage)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        BoundingBoxView(
                            boxes: viewModel.predictions.map { $0.boundingBox },
                            labels: viewModel.predictions.map { $0.label },
                            color: .red
                        )
                    )

                    .onAppear {
                        viewModel.predict(image: testImage)
                    }
            } else {
                Text("❌ Test image not found.")
            }
        }
        .padding()
    }
}

