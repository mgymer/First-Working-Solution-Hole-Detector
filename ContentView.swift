import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = DetectionViewModel(predictor: CombinedPredictor.shared)
    @StateObject var cameraService = CameraService()

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreview(session: cameraService.getSession())
                .ignoresSafeArea()

            // HOLES (blue)
            BoundingBoxView(
                boxes:  viewModel.predictions
                    .filter { $0.label == "hole" }
                    .map { $0.boundingBox },
                labels: viewModel.predictions
                    .filter { $0.label == "hole" }
                    .map { "hole \(Int($0.confidence * 100))%" },
                color: .blue
            )
            .ignoresSafeArea()
            .zIndex(0)

            // BALLS (green) on top
            BoundingBoxView(
                boxes:  viewModel.predictions
                    .filter { $0.label == "ball" }
                    .map { $0.boundingBox },
                labels: viewModel.predictions
                    .filter { $0.label == "ball" }
                    .map { "ball \(Int($0.confidence * 100))%" },
                color: .green
            )
            .ignoresSafeArea()
            .zIndex(1)

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
