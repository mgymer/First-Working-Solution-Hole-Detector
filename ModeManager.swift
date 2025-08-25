import Combine

enum DetectionMode: String, CaseIterable, Identifiable {
    case ml = "ML"
    case deterministic = "Det"
    var id: Self { self }   // lets ForEach work without “id: \.self”
}

final class ModeManager: ObservableObject {
    static let shared = ModeManager()
    @Published var mode: DetectionMode = .ml
    private init() {}
}
