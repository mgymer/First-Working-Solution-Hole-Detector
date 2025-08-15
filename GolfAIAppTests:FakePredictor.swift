import CoreVideo
@testable import GolfAIApp

struct FakePredictor: Predictor {
    let fakeResults: [Prediction]
    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] { fakeResults }
}
