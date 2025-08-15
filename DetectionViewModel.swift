import Foundation
import Combine
import UIKit
import CoreVideo

// Only import these if you actually use them elsewhere in this file
// import Vision
// import CoreML
// import AVFoundation

final class DetectionViewModel: NSObject, ObservableObject {
    @Published var predictions: [Prediction] = []
    @Published var debugMessage: String = "Awaiting input..."

    private let predictor: Predictor

    // Dependency injection so we can use a FakePredictor in tests
    init(predictor: Predictor = YOLOPredictor.shared) {
        self.predictor = predictor
        super.init()
    }

    // MARK: - Update Predictions
    func update(with predictions: [Prediction]) {
        self.predictions = predictions
        self.debugMessage = predictions.isEmpty
            ? "⚠️ No predictions"
            : "✅ \(predictions.count) object(s) detected"
    }

    // MARK: - Manual Image Prediction (for test image)
    func predict(image: UIImage) {
        // Requires UIImageResize.swift in the target (for .resized and .toCVPixelBuffer)
        guard let resizedImage = image.resized(to: CGSize(width: 416, height: 416)) else {
            print("❌ Could not resize image")
            return
        }
        guard let pixelBuffer = resizedImage.toCVPixelBuffer(size: CGSize(width: 416, height: 416)) else {
            print("❌ Could not convert image to CVPixelBuffer")
            return
        }

        let results = predictor.predict(pixelBuffer: pixelBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.update(with: results)
        }
    }
}

