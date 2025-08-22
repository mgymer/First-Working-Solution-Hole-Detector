import SwiftUI
import Combine
import ImageIO
import ARKit      // <-- add this


private let LIDAR_ENABLED = true   // true = ARKit owns camera; false = AVFoundation pipeline

struct ContentView: View {
    @StateObject var viewModel = DetectionViewModel(predictor: CombinedPredictor.shared)
    @StateObject var cameraService = CameraService()           // used only when LIDAR_ENABLED == false
    @StateObject var lidar = LiDARService.shared               // used only when LIDAR_ENABLED == true

    @State private var holeScreen: CGPoint?
    @State private var ballScreen: CGPoint?
    @State private var downhillVecFromBall: CGVector?

    // simple throttle for AR-frame inference
    @State private var lastInferenceTime: Date = .distantPast
    private let frameGap: TimeInterval = 0.20

    var body: some View {
        ZStack {
            Group {
                if LIDAR_ENABLED {
                    ARPreview(session: lidar.session)
                } else {
                    CameraPreview(session: cameraService.getSession())
                }
            }
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

            // Lines
            if let b = ballScreen, let h = holeScreen {
                PathOverlay(ball: b, hole: h, downhillFromBall: downhillVecFromBall)
                    .zIndex(2)
            }

            // HUD
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
        // Quick test button
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

        // Lifecycle
        .onAppear {
            if LIDAR_ENABLED {
                lidar.start()                         // ARKit owns camera
            } else {
                cameraService.start(viewModel: viewModel) // AVFoundation path (no LiDAR)
            }
        }
        .onDisappear {
            if LIDAR_ENABLED {
                lidar.stop()
            } else {
                cameraService.stop()
            }
        }

        // Run ML from AR frames (only when LiDAR/ARKit path is active)
        .onReceive(lidar.$latestFrame.compactMap { $0 }) { frame in
            guard LIDAR_ENABLED else { return }

            // throttle
            let now = Date()
            guard now.timeIntervalSince(lastInferenceTime) >= frameGap else { return }
            lastInferenceTime = now

            let pb = frame.capturedImage
            let exif: CGImagePropertyOrientation = .right // portrait

            DispatchQueue.global(qos: .userInitiated).async {
                let raw     = CombinedPredictor.shared.predictTryingCrops(pixelBuffer: pb, exifOrientation: exif)
                let refined = Heuristics.refine(predictions: raw)
                let stable  = Stabilizer.shared.update(with: refined)

                DispatchQueue.main.async {
                    viewModel.update(with: stable)
                }
            }
        }

        // Recompute lines when detections change
        .onReceive(viewModel.$predictions) { _ in
            updatePathInputs()
        }
    }

    // MARK: - Helpers

    private func updatePathInputs() {
        let size = UIScreen.main.bounds.size

        func screenPoint(from box: CGRect) -> CGPoint {
            CGPoint(x: box.midX * size.width, y: (1 - box.midY) * size.height)
        }

        let bestHole = viewModel.predictions
            .filter { $0.label == "hole" }
            .max(by: { $0.confidence < $1.confidence })

        let bestBall = viewModel.predictions
            .filter { $0.label == "ball" }
            .max(by: { $0.confidence < $1.confidence })

        holeScreen = bestHole.map { screenPoint(from: $0.boundingBox) }
        ballScreen = bestBall.map { screenPoint(from: $0.boundingBox) }

        if let ball = bestBall, LIDAR_ENABLED {
            let roi = smallROI(around: ball.boundingBox, fallbackSize: 0.10)
            if let proj = LiDARService.shared.projectedDownhill(at: roi, previewSize: size) {
                downhillVecFromBall = proj.dir
            } else {
                downhillVecFromBall = nil
            }
        } else {
            downhillVecFromBall = nil
        }
    }

    private func smallROI(around box: CGRect, fallbackSize: CGFloat) -> CGRect {
        let cx = box.midX, cy = box.midY
        let w = max(fallbackSize, box.width * 1.2)
        let h = max(fallbackSize, box.height * 1.2)
        let x = min(max(0, cx - w/2), 1 - w)
        let y = min(max(0, cy - h/2), 1 - h)
        return CGRect(x: x, y: y, width: min(w, 1), height: min(h, 1))
    }
}
