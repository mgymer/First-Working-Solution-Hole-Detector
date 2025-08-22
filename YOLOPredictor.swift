import Foundation
import Vision
import CoreML
import CoreVideo
import ImageIO

final class YOLOPredictor: Predictor {
    static let shared = YOLOPredictor()

    private let vnModel: VNCoreMLModel
    private let confidenceThreshold: VNConfidence = 0.15

    private init() {
        do {
            let ml = try GolfHoleDetector(configuration: MLModelConfiguration()).model
            self.vnModel = try VNCoreMLModel(for: ml)
        } catch {
            fatalError("❌ Failed to load GolfHoleDetector.mlpackage: \(error)")
        }
    }

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        return predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }
}

extension YOLOPredictor {
    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        return predict(pixelBuffer: pixelBuffer, exifOrientation: exifOrientation, using: .scaleFit)
    }

    func predictTryingCrops(pixelBuffer: CVPixelBuffer,
                            exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        let order: [VNImageCropAndScaleOption] = [.scaleFit, .centerCrop, .scaleFill]
        for crop in order {
            let res = predict(pixelBuffer: pixelBuffer, exifOrientation: exifOrientation, using: crop)
            if !res.isEmpty {
                print("✅ Using crop (hole):", crop.rawValue)
                return res
            }
        }
        print("❌ No hole detections with any crop mode")
        return []
    }
}

private extension YOLOPredictor {
    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation,
                 using crop: VNImageCropAndScaleOption) -> [Prediction] {

        var out: [Prediction] = []

        let request = VNCoreMLRequest(model: vnModel) { [confidenceThreshold] req, err in
            if let err = err { print("❌ Vision (hole) error:", err); return }
            guard let obs = req.results as? [VNRecognizedObjectObservation] else { return }

            for o in obs {
                let conf = o.labels.first?.confidence ?? o.confidence
                guard conf >= confidenceThreshold else { continue }
                out.append(Prediction(label: "hole", confidence: conf, boundingBox: o.boundingBox))
            }
        }

        request.imageCropAndScaleOption = crop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: exifOrientation,
                                            options: [:])
        do { try handler.perform([request]) }
        catch { print("❌ Vision perform (hole) error:", error) }

        return out
    }
}
