import Foundation
import Vision
import CoreML
import CoreVideo
import ImageIO

final class BallModelPredictor: Predictor {
    static let shared = BallModelPredictor()

    private let vnModel: VNCoreMLModel
    private let confidenceThreshold: VNConfidence = 0.10   // was 0.25


    private init() {
        do {
            guard let url = Bundle.main.url(forResource: "BallDetectorBEST", withExtension: "mlmodelc") else {
                fatalError("❌ BallDetectorBEST.mlmodelc not found in bundle. Check target membership + Copy Bundle Resources.")
            }
            let mlModel = try MLModel(contentsOf: url)
            self.vnModel = try VNCoreMLModel(for: mlModel)
        } catch {
            fatalError("❌ Failed to load BallDetectorBEST model: \(error)")
        }
    }

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }

    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: exifOrientation, using: .scaleFit)
    }

    func predictTryingCrops(pixelBuffer: CVPixelBuffer,
                            exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        for crop in [VNImageCropAndScaleOption.scaleFit, .centerCrop, .scaleFill] {
            let r = predict(pixelBuffer: pixelBuffer, exifOrientation: exifOrientation, using: crop)
            if !r.isEmpty { return r }
        }
        return []
    }

    private func predict(pixelBuffer: CVPixelBuffer,
                         exifOrientation: CGImagePropertyOrientation,
                         using crop: VNImageCropAndScaleOption) -> [Prediction] {
        var out: [Prediction] = []

        let request = VNCoreMLRequest(model: vnModel) { [confidenceThreshold] req, err in
            if let err = err { print("❌ Vision (ball) error:", err); return }
            guard let obs = req.results as? [VNRecognizedObjectObservation] else { return }

            for o in obs {
                let conf = o.labels.first?.confidence ?? o.confidence
                guard conf >= confidenceThreshold else { continue }
                out.append(Prediction(label: "ball", confidence: conf, boundingBox: o.boundingBox))
            }
        }

        request.imageCropAndScaleOption = crop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: exifOrientation,
                                            options: [:])
        do { try handler.perform([request]) }
        catch { print("❌ Vision perform (ball) error:", error) }

        return out
    }
}
