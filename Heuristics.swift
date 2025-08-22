// Heuristics.swift
import CoreGraphics

enum Heuristics {
    // -------- Tunables (safe defaults) --------
    // Areas are in normalized [0,1] image coordinates.
    static let minBallArea: CGFloat = 0.000005   // allow very small balls
    static let maxBallArea: CGFloat = 0.03

    static let minHoleArea: CGFloat = 0.00015
    static let maxHoleArea: CGFloat = 0.25

    // Keep shapes roughly circular-ish; widen if you get false drops
    static let ballAspectRange: ClosedRange<CGFloat> = 0.60...1.67   // w/h or h/w
    static let holeAspectRange: ClosedRange<CGFloat> = 0.60...1.67

    // Optional positional prior (Vision boxes are bottom-left origin, y↑)
    // Require the hole center not to be too near the top edge (tweak as you like)
    static let minHoleCenterY: CGFloat = 0.05

    // Suppression / tie-breaking
    static let nmsIoU: CGFloat   = 0.50     // class-wise NMS
    static let crossIoU: CGFloat = 0.50     // when ball & hole overlap this much…
    static let ballVsHoleAreaRatio: CGFloat = 0.70
    // If ballArea / holeArea <= ratio ⇒ prefer BALL (drop the hole)

    // -------- Public entry point --------
    static func refine(predictions: [Prediction]) -> [Prediction] {
        // 1) Simple area + aspect + (optional) position gates
        let areaFiltered = predictions.filter { p in
            let a = area(p.boundingBox)
            let asp = aspect(p.boundingBox)
            switch p.label {
            case "ball":
                return a >= minBallArea && a <= maxBallArea &&
                       ballAspectRange.contains(asp)
            case "hole":
                let okArea  = a >= minHoleArea && a <= maxHoleArea
                let okAsp   = holeAspectRange.contains(asp)
                let okPosY  = p.boundingBox.midY >= minHoleCenterY
                return okArea && okAsp && okPosY
            default:
                return true
            }
        }

        // 2) Class-wise NMS
        let ballsNMS = nms(areaFiltered.filter { $0.label == "ball" }, iouThresh: nmsIoU)
        let holesNMS = nms(areaFiltered.filter { $0.label == "hole" }, iouThresh: nmsIoU)

        // 3) Cross-class conflict resolution when boxes overlap
        var keepBall = Array(repeating: true, count: ballsNMS.count)
        var keepHole = Array(repeating: true, count: holesNMS.count)

        for i in ballsNMS.indices where keepBall[i] {
            for j in holesNMS.indices where keepHole[j] {
                if iou(ballsNMS[i].boundingBox, holesNMS[j].boundingBox) >= crossIoU {
                    let ai = area(ballsNMS[i].boundingBox)
                    let aj = area(holesNMS[j].boundingBox)
                    // smaller ball than (ratio * hole) ⇒ prefer BALL (drop HOLE)
                    if ai / max(aj, 1e-6) <= ballVsHoleAreaRatio {
                        keepHole[j] = false
                    } else {
                        keepBall[i] = false
                    }
                }
            }
        }

        // 4) Gather survivors (fix for enumerated() tuple)
        let balls = ballsNMS.enumerated().compactMap { keepBall[$0.offset] ? $0.element : nil }
        let holes = holesNMS.enumerated().compactMap { keepHole[$0.offset] ? $0.element : nil }
        return balls + holes
    }

    // -------- Helpers --------
    private static func area(_ r: CGRect) -> CGFloat { r.width * r.height }

    // aspect ratio invariant to orientation: max(w/h, h/w)
    private static func aspect(_ r: CGRect) -> CGFloat {
        let w = max(r.width, 1e-6), h = max(r.height, 1e-6)
        return max(w/h, h/w)
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let interRect = a.intersection(b)
        if interRect.isNull || interRect.isEmpty { return 0 }
        let inter = interRect.width * interRect.height
        let ua = a.width * a.height
        let ub = b.width * b.height
        let denom = ua + ub - inter
        return denom > 0 ? inter / denom : 0
    }

    private static func nms(_ preds: [Prediction], iouThresh: CGFloat) -> [Prediction] {
        var sorted = preds.sorted { $0.confidence > $1.confidence }
        var keep: [Prediction] = []
        while !sorted.isEmpty {
            let p = sorted.removeFirst()
            keep.append(p)
            sorted.removeAll { q in iou(p.boundingBox, q.boundingBox) >= iouThresh }
        }
        return keep
    }
}
