import UIKit
import AVFoundation

class ViewController: UIViewController {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let cameraService = CameraService()
    private let predictor = YOLOPredictor.shared
    private let viewModel = DetectionViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup camera preview
        cameraService.setPreviewInView(self.view)

        // Handle frame-by-frame prediction
        cameraService.setBufferHandler { [weak self] buffer in
            guard let self = self else { return }
            let predictions = predictor.predict(pixelBuffer: buffer)
            DispatchQueue.main.async {
                self.viewModel.predictions = predictions
                self.viewModel.debugMessage = predictions.isEmpty ? "⚠️ No predictions" : "✅ \(predictions.count) golf hole(s) detected"
            }
        }

        cameraService.startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraService.stopSession()
    }
}

