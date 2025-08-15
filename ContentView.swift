import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = DetectionViewModel()
    @StateObject var cameraService = CameraService()

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreview(session: cameraService.getSession())
                .ignoresSafeArea()

            // Bounding boxes for predictions
            BoundingBoxView(
                boxes: viewModel.predictions.map { $0.boundingBox },
                labels: viewModel.predictions.map { $0.label },
                color: .green
            )
            .ignoresSafeArea()

            // Debug overlay
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
        .onAppear {
            cameraService.start(viewModel: viewModel)
        }
        .onDisappear {
            cameraService.stop()
        }
    }
}
