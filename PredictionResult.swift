import Foundation
import CoreGraphics

struct Prediction {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
