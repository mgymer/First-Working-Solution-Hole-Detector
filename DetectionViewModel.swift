import Foundation
import Vision
import CoreML
import AVFoundation
import UIKit  // 👈 Required for UIImage

class DetectionViewModel: NSObject, ObservableObject {
    @Published var predictions: [Prediction] = []
    @Published var debugMessage: String = "Awaiting input..."

    private let predictor = YOLOPredictor.shared

    // MARK: - Update Predictions
    func update(with predictions: [Prediction]) {
        self.predictions = predictions
        self.debugMessage = predictions.isEmpty
            ? "⚠️ No predictions"
            : "✅ \(predictions.count) object(s) detected"
    }

    // MARK: - Manual Image Prediction (for test image)
    func predict(image: UIImage) {
        guard let resizedImage = image.resized(to: CGSize(width: 416, height: 416)) else {
            print("❌ Could not resize image")
            return
        }

        guard let pixelBuffer = resizedImage.toCVPixelBuffer(size: CGSize(width: 416, height: 416)) else {
            print("❌ Could not convert image to CVPixelBuffer")
            return
        }

        let results = predictor.predict(pixelBuffer: pixelBuffer)
        DispatchQueue.main.async {
            self.update(with: results)
        }
    }
    }
