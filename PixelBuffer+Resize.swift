import CoreVideo
import CoreImage
import UIKit

extension CVPixelBuffer {
    func resized(to size: CGSize) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let scaleX = size.width / CGFloat(CVPixelBufferGetWidth(self))
        let scaleY = size.height / CGFloat(CVPixelBufferGetHeight(self))
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let resizedImage = ciImage.transformed(by: transform)

        let context = CIContext()
        var resizedBuffer: CVPixelBuffer?

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &resizedBuffer
        )

        guard let buffer = resizedBuffer else {
            print("❌ Failed to create resized pixel buffer")
            return nil
        }

        context.render(resizedImage, to: buffer)
        return buffer
    }
}

