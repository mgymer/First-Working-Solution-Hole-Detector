// YOLOPredictor.swift (top of the file)
import Foundation
import Vision
import CoreML
import CoreVideo

final class YOLOPredictor: Predictor {
    static let shared = YOLOPredictor()

    private let vnModel: VNCoreMLModel
    private let confidenceThreshold: VNConfidence = 0.05
    private let allowedLabels: Set<String> = []   // ← allow all while debugging
    // If you confirm the class is exactly "hole", set this back to ["hole"] later.


    private init() {
        do {
            let ml = try GolfHoleDetector(configuration: MLModelConfiguration()).model
            self.vnModel = try VNCoreMLModel(for: ml)
        } catch {
            fatalError("❌ Failed to load GolfHoleDetector.mlpackage: \(error)")
        }
    }

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        var results: [Prediction] = []

        let request = VNCoreMLRequest(model: vnModel) { [confidenceThreshold, allowedLabels] req, error in
            guard error == nil,
                  let obs = req.results as? [VNRecognizedObjectObservation] else { return }

            for o in obs {
                let top  = o.labels.first
                let id   = top?.identifier ?? "unknown"
                let conf = top?.confidence ?? o.confidence

                print("🔎 obs=\(id) conf=\(String(format: "%.3f", Double(conf))) box=\(o.boundingBox)")

                guard conf >= confidenceThreshold else { continue }
                if !allowedLabels.isEmpty && !allowedLabels.contains(id) { continue }

                results.append(Prediction(label: id, confidence: conf, boundingBox: o.boundingBox))
            }
        }
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        return results
    }
}

