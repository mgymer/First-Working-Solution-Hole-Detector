import Combine

enum DetectionMode: String, CaseIterable, Identifiable {
    case ml = "ML"
    case deterministic = "Deterministic"
    var id: String { rawValue }
}

final class ModeManager: ObservableObject {
    static let shared = ModeManager()
    @Published var mode: DetectionMode = .ml
    private init() {}
}
