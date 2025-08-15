import Foundation
import CoreVideo

final class YOLOPredictor: Predictor {
    static let shared = YOLOPredictor()
    private init() {}

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        // STUB for now; returns none. Replace with real Vision/CoreML later.
        return []
    }
}
