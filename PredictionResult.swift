import Foundation
import CoreGraphics

struct Prediction: Equatable {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}

