import XCTest
@testable import GolfAIApp

@MainActor
final class DetectionViewModelTests: XCTestCase {

    func test_update_noPredictions_setsWarning() {
        let vm = DetectionViewModel(predictor: FakePredictor(fakeResults: []))
        vm.update(with: [])
        XCTAssertEqual(vm.predictions.count, 0)
        XCTAssertTrue(vm.debugMessage.contains("No predictions"))
    }

    func test_update_onePrediction_setsSuccess() {
        let p = Prediction(label: "golf_ball", confidence: 0.91,
                           boundingBox: .init(x: 0.45, y: 0.55, width: 0.10, height: 0.10))
        let vm = DetectionViewModel(predictor: FakePredictor(fakeResults: [p]))
        vm.update(with: [p])
        XCTAssertEqual(vm.predictions.count, 1)
        XCTAssertTrue(vm.debugMessage.contains("1 object"))
    }
}
