import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = DetectionViewModel(predictor: YOLOPredictor.shared)
    @StateObject var cameraService = CameraService()
    // ...



    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreview(session: cameraService.getSession())
                .ignoresSafeArea()

            // Bounding boxes for predictions (with confidence)
            BoundingBoxView(
                boxes:  viewModel.predictions.map { $0.boundingBox },
                labels: viewModel.predictions.map {
                    let pct = Int(($0.confidence as Float) * 100)
                    return "\($0.label) \(pct)%"
                },
                color: .green
            )
            .ignoresSafeArea()

            // Debug overlay text at bottom
            VStack {
                Spacer()
                Text(viewModel.debugMessage)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        // 🔹 Test Box overlay button (top-left)
        .overlay(
            VStack {
                HStack {
                    Button("▶️ Test Box") {
                        let fake = Prediction(
                            label: "test",
                            confidence: 0.9,
                            boundingBox: CGRect(x: 0.45, y: 0.45, width: 0.10, height: 0.10)
                        )
                        viewModel.update(with: [fake])
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Spacer()
                }
                Spacer()
            }
            .padding(),
            alignment: .topLeading
        )
        .onAppear { cameraService.start(viewModel: viewModel) }
        .onDisappear { cameraService.stop() }
    }
}
