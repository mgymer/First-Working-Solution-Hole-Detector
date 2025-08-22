import Foundation
import Vision
import CoreML
import CoreVideo
import ImageIO // CGImagePropertyOrientation

/// Runs the BallDetectorBEST.mlpackage and emits label "ball".
final class BallModelPredictor: Predictor {
    static let shared = BallModelPredictor()

    private let vnModel: VNCoreMLModel
    private let confidenceThreshold: VNConfidence = 0.10

    private init() {
        do {
            // Load the *compiled* model from the app bundle.
            // (Works regardless of the auto-generated Swift class name.)
            guard let url = Bundle.main.url(forResource: "BallDetectorBEST", withExtension: "mlmodelc") else {
                fatalError("❌ BallDetectorBEST.mlmodelc not found in bundle. Check target membership + Copy Bundle Resources.")
            }
            let mlModel = try MLModel(contentsOf: url)
            self.vnModel = try VNCoreMLModel(for: mlModel)
        } catch {
            fatalError("❌ Failed to load BallDetectorBEST model: \(error)")
        }
    }

    // MARK: - Predictor (no EXIF)
    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }

    // MARK: - Public helpers (EXIF aware)
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

    // MARK: - Core Vision invocation
    private func predict(pixelBuffer: CVPixelBuffer,
                         exifOrientation: CGImagePropertyOrientation,
                         using crop: VNImageCropAndScaleOption) -> [Prediction] {
        var out: [Prediction] = []

        let request = VNCoreMLRequest(model: vnModel) { [confidenceThreshold] req, err in
            if let err = err {
                print("❌ Vision (ball) error:", err)
                return
            }
            guard let obs = req.results as? [VNRecognizedObjectObservation] else { return }

            for o in obs {
                let conf = o.labels.first?.confidence ?? o.confidence
                guard conf >= confidenceThreshold else { continue }
                // 🔹 Force a stable label so UI filters work
                out.append(Prediction(label: "ball",
                                      confidence: conf,
                                      boundingBox: o.boundingBox))
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
