// ModelTest.swift – leave in project (no test target membership needed)
import SwiftUI
import UIKit

struct ModelTest: View {
    @StateObject private var viewModel: DetectionViewModel

    init() {
        _viewModel = StateObject(wrappedValue: DetectionViewModel(predictor: YOLOPredictor.shared))
    }

    var body: some View {
        VStack {
            if let img = UIImage(named: "test_sample") {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        BoundingBoxView(
                            boxes: viewModel.predictions.map { $0.boundingBox },
                            labels: viewModel.predictions.map {
                                let pct = Int(($0.confidence as Float) * 100)
                                return "\($0.label) \(pct)%"
                            },
                            color: .red
                        )
                    )
                    .onAppear {
                        let size = CGSize(width: 640, height: 640)
                        if let resized = img.resized(to: size),
                           let pb = resized.toCVPixelBuffer(size: size) {
                            
                            print("📸 Test image resized and converted to CVPixelBuffer ✅")
                            
                            let results = YOLOPredictor.shared.predictTryingCrops(pixelBuffer: pb, exifOrientation: .up)
                            
                            print("🧠 Prediction count: \(results.count)")
                            for prediction in results {
                                print("→ Label: \(prediction.label), Confidence: \(prediction.confidence), Box: \(prediction.boundingBox)")
                            }
                            
                            viewModel.update(with: results)
                        } else {
                            print("⚠️ Could not create CVPixelBuffer from test image")
                            viewModel.update(with: [])
                        }
                    }
            } else {
                Text("❌ test_sample not found")
            }
        }
        .padding()
    }
}

