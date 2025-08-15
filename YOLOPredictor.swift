import Foundation
import Vision
import CoreML
import CoreVideo



class YOLOPredictor {
    // Safe singleton you can use anywhere
    static let shared: YOLOPredictor = {
        guard let p = YOLOPredictor() else {
            fatalError("GolfHoleDetector.mlmodel failed to load")
        }
        return p
    }()

    private let vnModel: VNCoreMLModel
    private let confidenceThreshold: VNConfidence = 0.1

    init?() {
        do {
            let coreMLModel = try GolfHoleDetector(configuration: MLModelConfiguration()).model
            self.vnModel = try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("❌ Failed to load model: \(error.localizedDescription)")
            return nil
        }
    }

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        var results: [Prediction] = []

        let request = VNCoreMLRequest(model: vnModel) { [self] request, error in
            if let error = error {
                print("⚠️ VNCoreMLRequest failed: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                print("⚠️ Unexpected result type from Vision request")
                return
            }

            for observation in observations where observation.confidence > self.confidenceThreshold {
                let topLabel = observation.labels.first?.identifier ?? "N/A"
                results.append(
                    Prediction(
                        label: topLabel,
                        confidence: observation.confidence,
                        boundingBox: observation.boundingBox
                    )
                )
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do { try handler.perform([request]) }
        catch { print("❌ Failed to perform request: \(error.localizedDescription)") }

        return results
    }
}

