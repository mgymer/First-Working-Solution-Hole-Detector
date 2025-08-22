import CoreVideo
import ImageIO

/// Calls both predictors and returns a concatenated list.
final class CombinedPredictor: Predictor {
    static let shared = CombinedPredictor()
    private init() {}

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }

    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        let holes = YOLOPredictor.shared.predict(pixelBuffer: pixelBuffer,
                                                 exifOrientation: exifOrientation)
        let balls = BallModelPredictor.shared.predict(pixelBuffer: pixelBuffer,
                                                      exifOrientation: exifOrientation)
        return holes + balls
    }

    func predictTryingCrops(pixelBuffer: CVPixelBuffer,
                            exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        let holes = YOLOPredictor.shared.predictTryingCrops(pixelBuffer: pixelBuffer,
                                                            exifOrientation: exifOrientation)
        let balls = BallModelPredictor.shared.predictTryingCrops(pixelBuffer: pixelBuffer,
                                                                 exifOrientation: exifOrientation)
        return holes + balls
    }
}
