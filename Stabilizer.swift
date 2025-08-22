import Foundation
import CoreGraphics

final class Stabilizer {
    static let shared = Stabilizer()

    private struct Track {
        var id = UUID()
        var label: String
        var box: CGRect
        var conf: Float
        var hits: Int
        var miss: Int
    }

    private var tracks: [Track] = []
    var requiredHits = 1       // was 2 (show a track immediately)
    var maxMiss = 3            // was 2
    var matchIoU: CGFloat = 0.25  // was 0.30 (easier to match)
    var smooth: CGFloat = 0.6     // was 0.5 (slightly stronger smoothing)


    private init() {}

    func reset() { tracks.removeAll() }

    func update(with detections: [Prediction]) -> [Prediction] {
        var updated = Array(repeating: false, count: tracks.count)
        var assigned = Array(repeating: false, count: detections.count)

        // assign by IoU + same label
        for (di, d) in detections.enumerated() {
            var best = -1
            var bestIoU: CGFloat = 0
            for (ti, t) in tracks.enumerated() where !updated[ti] && t.label == d.label {
                let i = Heuristics.iou(t.box, d.boundingBox)
                if i > bestIoU {
                    bestIoU = i
                    best = ti
                }
            }
            if best >= 0 && bestIoU >= matchIoU {
                // smooth box
                let tb = tracks[best].box
                let nb = CGRect(
                    x: tb.origin.x * (1 - smooth) + d.boundingBox.origin.x * smooth,
                    y: tb.origin.y * (1 - smooth) + d.boundingBox.origin.y * smooth,
                    width: tb.size.width * (1 - smooth) + d.boundingBox.size.width * smooth,
                    height: tb.size.height * (1 - smooth) + d.boundingBox.size.height * smooth
                )
                tracks[best].box = nb
                tracks[best].conf = max(tracks[best].conf, d.confidence)
                tracks[best].hits += 1
                tracks[best].miss = 0
                updated[best] = true
                assigned[di] = true
            }
        }

        // new tracks for unassigned detections
        for (i, d) in detections.enumerated() where !assigned[i] {
            tracks.append(Track(label: d.label, box: d.boundingBox, conf: d.confidence, hits: 1, miss: 0))
        }

        // age unmatched tracks
        for i in tracks.indices where !updated.indices.contains(i) || !updated[i] {
            tracks[i].miss += 1
        }

        // drop stale
        tracks.removeAll { $0.miss > maxMiss }

        // emit only confirmed tracks
        return tracks
            .filter { $0.hits >= requiredHits }
            .map { Prediction(label: $0.label, confidence: $0.conf, boundingBox: $0.box) }
    }
}
