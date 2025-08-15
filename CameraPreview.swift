import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        // ✅ Set the preview layer’s connection rotation (iOS 17+ API)
        if let conn = previewLayer.connection,
           conn.isVideoRotationAngleSupported(0) {
            conn.videoRotationAngle = 0   // portrait
        }

        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // keep layer sized to view
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
