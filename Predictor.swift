import CoreVideo

protocol Predictor {
    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction]
}
