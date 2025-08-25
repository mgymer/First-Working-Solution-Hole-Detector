import ARKit
import CoreGraphics
import simd
import UIKit

final class DepthSizer {
    static let shared = DepthSizer()
    private init() {}

    /// Returns:
    ///  - true  => size matches expectation (keep)
    ///  - false => size inconsistent (drop)
    ///  - nil   => no decision (no depth / no frame)
    func passesSizeCheck(normBox: CGRect, expectedInches: CGFloat) -> Bool? {
        guard let frame = LiDARService.shared.latestFrame else { return nil }

        // Depth at box center (map via displayTransform using the current viewport)
        let viewport = UIScreen.main.bounds.size
        guard let world = LiDARService.shared.worldPointAtCenter(of: normBox, previewSize: viewport) else {
            return nil
        }

        // Camera position & depth
        let camM = frame.camera.transform
        let camPos = simd_float3(camM.columns.3.x, camM.columns.3.y, camM.columns.3.z)
        let depth = simd_length(world - camPos)
        if !depth.isFinite || depth <= 0.05 { return nil }

        // Focal length in pixels (capture space)
        let intr = frame.camera.intrinsics
        let fpx = max(intr.columns.0.x, intr.columns.1.y)

        // Expected diameter in pixels at this depth (pinhole approx)
        let meters = Float(expectedInches * 0.0254)
        let expectedPx = CGFloat(fpx) * CGFloat(meters / depth)

        // Measured diameter from bounding box in CAPTURE pixel space
        let capW = CGFloat(CVPixelBufferGetWidth(frame.capturedImage))
        let capH = CGFloat(CVPixelBufferGetHeight(frame.capturedImage))
        let measPx = 0.5 * ((normBox.width * capW) + (normBox.height * capH))

        // Tolerance (looser for the larger hole)
        let tol: CGFloat = (expectedInches < 3) ? 0.6 : 0.5
        return measPx >= expectedPx * (1 - tol) && measPx <= expectedPx * (1 + tol)
    }
}
