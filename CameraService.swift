import Foundation
import AVFoundation
import Vision
import Combine

final class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput!
    private var lastPredictionTime = Date.distantPast
    private weak var viewModel: DetectionViewModel?

    public func getSession() -> AVCaptureSession { session }

    func start(viewModel: DetectionViewModel) {
        self.viewModel = viewModel

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("❌ Could not create AVCaptureDeviceInput")
            return
        }

        self.input = input

        session.beginConfiguration()
        session.sessionPreset = .high

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Set orientation AFTER adding output
        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                // iOS 17+: rotation angle in degrees. 0 = portrait
                if conn.isVideoRotationAngleSupported(0) {
                    conn.videoRotationAngle = 0
                }
            } else {
                // iOS 16 and earlier
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
        }



        session.commitConfiguration()
        startSession()
    }

    public func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    public func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    // MARK: - Frame Capture
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        print("📷 frame: \(w)x\(h)")

        guard let resizedBuffer = pixelBuffer.resized(to: CGSize(width: 640, height: 640)) else { return }
        let rw = CVPixelBufferGetWidth(resizedBuffer)
        let rh = CVPixelBufferGetHeight(resizedBuffer)
        print("🪄 resized: \(rw)x\(rh)")

        let predictions = YOLOPredictor.shared.predict(pixelBuffer: resizedBuffer)
        print("🧠 predictions: \(predictions.count)")


        if !predictions.isEmpty {
            print("Labels seen:", Set(predictions.map { $0.label }))
        }
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.update(with: predictions)
        }
    }
}
