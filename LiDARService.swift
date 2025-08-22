import ARKit
import simd
import CoreGraphics
import Combine



struct SlopeResult {
    let angleDegrees: Float
    let downhillWorld: simd_float3
}

final class LiDARService: NSObject, ARSessionDelegate, ObservableObject {
    static let shared = LiDARService()

    let session = ARSession()
    @Published private(set) var latestFrame: ARFrame?

    private override init() { super.init() }

    func start() {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        cfg.sceneReconstruction = .mesh
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            cfg.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            cfg.frameSemantics.insert(.sceneDepth)
        }
        session.delegate = self
        session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
        latestFrame = nil
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            self.latestFrame = frame
        }
    }


    // MARK: Depth helpers

    func estimateSlope(roi: CGRect, previewSize: CGSize) -> SlopeResult? {
        guard let frame = latestFrame else { return nil }
        guard let sceneDepth = frame.sceneDepth ?? frame.smoothedSceneDepth else { return nil }

        let depth = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }

        let dw = CVPixelBufferGetWidth(depth)
        let dh = CVPixelBufferGetHeight(depth)
        guard let base = CVPixelBufferGetBaseAddress(depth) else { return nil }
        let ptr = base.assumingMemoryBound(to: Float32.self)

        let t = frame.displayTransform(for: .portrait, viewportSize: previewSize)

        func mapPoint(_ p: CGPoint) -> CGPoint {
            let ndc = CGPoint(x: p.x, y: 1 - p.y)
            let ui = ndc.applying(t)
            return CGPoint(x: ui.x * CGFloat(dw), y: ui.y * CGFloat(dh))
        }

        let pMin = mapPoint(CGPoint(x: roi.minX, y: roi.minY))
        let pMax = mapPoint(CGPoint(x: roi.maxX, y: roi.maxY))
        let rx0 = max(0, Int(min(pMin.x, pMax.x)))
        let ry0 = max(0, Int(min(pMin.y, pMax.y)))
        let rx1 = min(dw - 1, Int(max(pMin.x, pMax.x)))
        let ry1 = min(dh - 1, Int(max(pMin.y, pMax.y)))
        if rx1 - rx0 < 4 || ry1 - ry0 < 4 { return nil }

        var xs:[Float]=[], zs:[Float]=[], ys:[Float]=[]

        let intr = frame.camera.intrinsics
        let camToWorld = frame.camera.transform

        func backproject(u:Int, v:Int, z:Float) -> simd_float3 {
            let fx = intr.columns.0.x, fy = intr.columns.1.y
            let cx = intr.columns.2.x, cy = intr.columns.2.y
            let Xc = (Float(u) - cx) * z / fx
            let Yc = (Float(v) - cy) * z / fy
            let camP = simd_float4(Xc, Yc, z, 1)
            let worldP = camToWorld * camP
            return simd_float3(worldP.x, worldP.y, worldP.z)
        }

        let stepX = max(1, (rx1 - rx0) / 24)
        let stepY = max(1, (ry1 - ry0) / 24)
        for v in stride(from: ry0, through: ry1, by: stepY) {
            for u in stride(from: rx0, through: rx1, by: stepX) {
                let z = ptr[v * dw + u]
                if !z.isFinite || z <= 0.05 || z > 20 { continue }
                let p = backproject(u: u, v: v, z: z)
                xs.append(p.x); zs.append(p.z); ys.append(p.y)
            }
        }
        guard xs.count >= 20 else { return nil }

        var Sx:Float=0, Sz:Float=0, Sy:Float=0, Sxx:Float=0, Szz:Float=0, Sxz:Float=0, Sxy:Float=0, Syz:Float=0
        for i in 0..<xs.count {
            let x=xs[i], z=zs[i], y=ys[i]
            Sx += x; Sz += z; Sy += y
            Sxx += x*x; Szz += z*z; Sxz += x*z
            Sxy += x*y; Syz += z*y
        }
        let n = Float(xs.count)
        let A = simd_float3x3(
            .init(Sxx, Sxz, Sx),
            .init(Sxz, Szz, Sz),
            .init(Sx,  Sz,  n )
        )
        let B = simd_float3(Sxy, Syz, Sy)
        let det = A.determinant
        if abs(det) < 1e-6 { return nil }
        let X = simd_inverse(A) * B
        let a = X.x, b = X.y

        let uphill = simd_normalize(simd_float3(a, 0, b))
        let downhill = -uphill
        let slopeAngle = atan(sqrt(a*a + b*b)) * 180 / .pi
        return SlopeResult(angleDegrees: slopeAngle, downhillWorld: downhill)
    }

    func worldPointAtCenter(of roi: CGRect, previewSize: CGSize) -> simd_float3? {
        guard let frame = latestFrame else { return nil }
        guard let sceneDepth = frame.sceneDepth ?? frame.smoothedSceneDepth else { return nil }

        let depth = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }

        let dw = CVPixelBufferGetWidth(depth)
        let dh = CVPixelBufferGetHeight(depth)
        guard let base = CVPixelBufferGetBaseAddress(depth) else { return nil }
        let ptr = base.assumingMemoryBound(to: Float32.self)

        let t = frame.displayTransform(for: .portrait, viewportSize: previewSize)
        let ndc = CGPoint(x: roi.midX, y: 1 - roi.midY).applying(t)
        let u = Int(clamping: Int(ndc.x * CGFloat(dw)))
        let v = Int(clamping: Int(ndc.y * CGFloat(dh)))

        let z = ptr[v * dw + u]
        if !z.isFinite || z <= 0.05 || z > 20 { return nil }

        let intr = frame.camera.intrinsics
        let camToWorld = frame.camera.transform
        let fx = intr.columns.0.x, fy = intr.columns.1.y
        let cx = intr.columns.2.x, cy = intr.columns.2.y
        let Xc = (Float(u) - cx) * z / fx
        let Yc = (Float(v) - cy) * z / fy
        let camP = simd_float4(Xc, Yc, z, 1)
        let worldP = camToWorld * camP
        return simd_float3(worldP.x, worldP.y, worldP.z)
    }

    func projectToScreen(_ world: simd_float3, previewSize: CGSize) -> CGPoint? {
        guard let frame = latestFrame else { return nil }
        let p = simd_float3(world.x, world.y, world.z)
        let sp = frame.camera.projectPoint(p, orientation: .portrait, viewportSize: previewSize)
        return sp
    }

    func projectedDownhill(at roi: CGRect, previewSize: CGSize, stepMeters: Float = 0.5)
    -> (anchor: CGPoint, dir: CGVector, angleDeg: Float)? {
        guard let slope = estimateSlope(roi: roi, previewSize: previewSize) else { return nil }
        guard let p0w = worldPointAtCenter(of: roi, previewSize: previewSize) else { return nil }
        let p1w = p0w + slope.downhillWorld * stepMeters
        guard let p0s = projectToScreen(p0w, previewSize: previewSize),
              let p1s = projectToScreen(p1w, previewSize: previewSize) else { return nil }
        let v = CGVector(dx: p1s.x - p0s.x, dy: p1s.y - p0s.y)
        let len = max(1.0, sqrt(v.dx*v.dx + v.dy*v.dy))
        return (anchor: p0s, dir: CGVector(dx: v.dx/len, dy: v.dy/len), angleDeg: slope.angleDegrees)
    }
}

private extension simd_float3x3 {
    var determinant: Float {
        let m = self
        return m.columns.0.x*(m.columns.1.y*m.columns.2.z - m.columns.1.z*m.columns.2.y)
             - m.columns.1.x*(m.columns.0.y*m.columns.2.z - m.columns.0.z*m.columns.2.y)
             + m.columns.2.x*(m.columns.0.y*m.columns.1.z - m.columns.0.z*m.columns.1.y)
    }
}
