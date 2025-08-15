import Combine
import UIKit

@MainActor
final class DetectionViewModel: NSObject, ObservableObject {
    @Published var predictions: [Prediction] = []
    @Published var debugMessage: String = "Awaiting input..."

    private let predictor: Predictor
    private var lastNonEmpty = Date.distantPast
    var holdSeconds: TimeInterval = 0.7

    // No default here anymore
    init(predictor: Predictor) {
        self.predictor = predictor
        super.init()
    }

    func update(with new: [Prediction]) {
        if new.isEmpty {
            if Date().timeIntervalSince(lastNonEmpty) < holdSeconds { return }
            predictions = []
            debugMessage = "⚠️ No predictions"
        } else {
            lastNonEmpty = Date()
            predictions = new
            debugMessage = "✅ \(new.count) object(s) detected"
        }
    }
}
