import Foundation
import Vision
import CoreML
import CoreVideo
import ImageIO   // CGImagePropertyOrientation

// MARK: - Predictor implementation
final class YOLOPredictor: Predictor {
    static let shared = YOLOPredictor()

    private let vnModel: VNCoreMLModel
    // Keep these generous for bring-up; we’ll tighten later
    private let confidenceThreshold: VNConfidence = 0.05
    private let allowedLabels: Set<String> = [] // allow all while debugging

    private init() {
        do {
            let ml = try GolfHoleDetector(configuration: MLModelConfiguration()).model
            self.vnModel = try VNCoreMLModel(for: ml)
        } catch {
            fatalError("❌ Failed to load GolfHoleDetector.mlpackage: \(error)")
        }
    }

    // --- Protocol requirement (no EXIF). Reasonable default for still images.
    // You can change to predictTryingCrops if you want multi-crop by default.
    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        return predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }
}

// MARK: - Public helpers
extension YOLOPredictor {

    /// Predict with a known EXIF orientation (preferred for camera path).
    /// Uses `.scaleFit` (letterbox) which usually matches YOLO preprocessing.
    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {
        return predict(pixelBuffer: pixelBuffer,
                       exifOrientation: exifOrientation,
                       using: .scaleFit)
    }

    /// Try 3 common YOLO crop modes and stop on first that yields results.
    /// Useful while bringing the model up if you’re getting 0 detections.
    func predictTryingCrops(pixelBuffer: CVPixelBuffer,
                            exifOrientation: CGImagePropertyOrientation) -> [Prediction] {

        let order: [VNImageCropAndScaleOption] = [.scaleFit, .centerCrop, .scaleFill]
        for crop in order {
            let res = predict(pixelBuffer: pixelBuffer,
                              exifOrientation: exifOrientation,
                              using: crop)
            if !res.isEmpty {
                print("✅ Using crop:", crop.rawValue)
                return res
            }
        }
        print("❌ No detections with any crop mode")
        return []
    }
}

// MARK: - Core Vision invocation (with crop mode)
private extension YOLOPredictor {

    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation,
                 using crop: VNImageCropAndScaleOption) -> [Prediction] {

        var out: [Prediction] = []

        // Build the request
        let request = VNCoreMLRequest(model: vnModel) { [confidenceThreshold, allowedLabels] req, err in
            if let err = err {
                print("❌ Vision error:", err)
                return
            }

            // If model doesn’t return object observations, show what we did get.
            if !(req.results is [VNRecognizedObjectObservation]) {
                let types = req.results?.map { String(describing: type(of: $0)) } ?? []
                if !types.isEmpty {
                    print("ℹ️ Vision returned non-object results:", types)
                }
            }

            guard let obs = req.results as? [VNRecognizedObjectObservation] else { return }
            if !(req.results is [VNRecognizedObjectObservation]) {
                let types = req.results?.map { String(describing: type(of: $0)) } ?? []
                print("ℹ️ Vision returned non-object results:", types)
            }

            // Optional debug: inspect first few observations
            print("🔎 obsCount:", obs.count)
            for o in obs.prefix(3) {
                let tops = o.labels.prefix(3).map { "\($0.identifier)=\($0.confidence)" }
                print("  ↳", tops.joined(separator: ", "), "box:", o.boundingBox)
            }

            for o in obs {
                let top  = o.labels.first
                let id   = top?.identifier ?? "unknown"
                let conf = top?.confidence ?? o.confidence

                guard conf >= confidenceThreshold else { continue }
                if !allowedLabels.isEmpty && !allowedLabels.contains(id) { continue }

                out.append(
                    Prediction(label: id,
                               confidence: conf,
                               boundingBox: o.boundingBox) // Vision’s normalized rect
                )
            }
        }

        // Crop/scale strategy for Vision → CoreML
        request.imageCropAndScaleOption = crop

        // Run the request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: exifOrientation,
                                            options: [:])
        do { try handler.perform([request]) }
        catch { print("❌ Vision perform error:", error) }

        return out
    }
}

