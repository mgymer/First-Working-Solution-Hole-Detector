import CoreVideo
import CoreGraphics
import CoreImage
import Vision
import UIKit

final class DeterministicDetector: Predictor {
    static let shared = DeterministicDetector()
    private init() {}

    // Knobs to tune on-course
    private let ballMinBrightness: CGFloat = 0.75
    private let holeMinBrightness: CGFloat = 0.60
    private let minCircularity: CGFloat = 0.55   // 0..1, 1 = perfect circle

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }

    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {

        var out: [Prediction] = []
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])      // grayscale
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.5])          // lift shadows

        if let ballBoxes = thresholdAndFindCircles(in: ci, thresh: ballMinBrightness) {
            out += sizeGateAndMap(ballBoxes, as: "ball")
        }
        if let holeBoxes = thresholdAndFindCircles(in: ci, thresh: holeMinBrightness) {
            out += sizeGateAndMap(holeBoxes, as: "hole")
        }
        return out
    }

    private func thresholdAndFindCircles(in image: CIImage, thresh: CGFloat) -> [CGRect]? {
        // Quick threshold in alpha via color matrix bias
        let bw = image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: Float(-thresh))
            ])
            .applyingFilter("CIColorClamp", parameters: [
                "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputMaxComponents": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])

        // Vision contour detection on the high-contrast image
        let req = VNDetectContoursRequest()
        req.contrastAdjustment = 1.0
        req.detectDarkOnLight = true
        let handler = VNImageRequestHandler(ciImage: bw, options: [:])

        do { try handler.perform([req]) } catch { return [] }
        guard let obs = req.results?.first else { return [] }

        var boxes: [CGRect] = []
        obs.topLevelContours.forEach { c in
            let bb = c.boundingBox // normalized [0,1], origin bottom-left
            let area = bb.width * bb.height
            guard area > 0.00002 else { return } // drop specks

            // crude circularity from bounding box squareness
            let circ = min(bb.width, bb.height) / max(bb.width, bb.height)
            if circ >= minCircularity { boxes.append(bb) }
        }
        return boxes
    }

    private func sizeGateAndMap(_ boxes: [CGRect], as label: String) -> [Prediction] {
        let expectedInches: CGFloat = (label == "ball") ? 1.68 : 4.25
        return boxes.compactMap { b in
            if let ok = DepthSizer.shared.passesSizeCheck(normBox: b, expectedInches: expectedInches), !ok {
                return nil
            }
            return Prediction(label: label, confidence: 0.6, boundingBox: b)
        }
    }
}
