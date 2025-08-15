import CoreVideo

@preconcurrency
protocol Predictor {
    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction]
}
