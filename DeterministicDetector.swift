import CoreVideo
import CoreGraphics
import CoreImage
import Vision
import UIKit

final class DeterministicDetector: Predictor {
    static let shared = DeterministicDetector()
    private init() {}

    // Tunables
    private let ballMinBrightness: CGFloat = 0.75
    private let holeMinBrightness: CGFloat = 0.60
    private let minCircularity: CGFloat = 0.55   // 0..1, 1 = perfect circle

    func predict(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        predict(pixelBuffer: pixelBuffer, exifOrientation: .up)
    }

    func predict(pixelBuffer: CVPixelBuffer,
                 exifOrientation: CGImagePropertyOrientation) -> [Prediction] {

        var out: [Prediction] = []

        // grayscale + slight exposure lift
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.5])

        if let ballBoxes = thresholdAndFindCircles(in: ci, thresh: ballMinBrightness) {
            out += sizeGateAndMap(ballBoxes, as: "ball")
        }
        if let holeBoxes = thresholdAndFindCircles(in: ci, thresh: holeMinBrightness) {
            out += sizeGateAndMap(holeBoxes, as: "hole")
        }
        return out
    }

    // MARK: - Contours on a thresholded image
    private func thresholdAndFindCircles(in image: CIImage, thresh: CGFloat) -> [CGRect]? {
        // Push pixels below 'thresh' toward 0 alpha -> high-contrast for Vision
        let bw = image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: -thresh)  // <-- CGFloat
            ])
            .applyingFilter("CIColorClamp", parameters: [
                "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputMaxComponents": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])

        let req = VNDetectContoursRequest()
        req.contrastAdjustment = 1.0
        // req.detectDarkOnLight = true  // deprecated; not needed with the thresholded image

        let handler = VNImageRequestHandler(ciImage: bw, options: [:])
        do { try handler.perform([req]) } catch { return [] }
        guard let obs = req.results?.first as? VNContoursObservation else { return [] }

        var boxes: [CGRect] = []
        for contour in obs.topLevelContours {
            // VNContour doesn't expose boundingBox; use its normalizedPath
            let bb = contour.normalizedPath.boundingBox   // normalized [0,1]
            let area = bb.width * bb.height
            guard area > 0.00002 else { continue }        // drop specks

            let circ = min(bb.width, bb.height) / max(bb.width, bb.height)
            if circ >= minCircularity { boxes.append(bb) }
        }
        return boxes
    }

    // MARK: - Size gating with LiDAR depth (optional)
    private func sizeGateAndMap(_ boxes: [CGRect], as label: String) -> [Prediction] {
        let expectedInches: CGFloat = (label == "ball") ? 1.68 : 4.25
        return boxes.compactMap { b in
            if let ok = DepthSizer.shared.passesSizeCheck(normBox: b, expectedInches: expectedInches),
               !ok { return nil }
            return Prediction(label: label, confidence: 0.6, boundingBox: b)
        }
    }
}
