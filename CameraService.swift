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
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

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

        // Throttle ~2 fps
        let now = Date()
        guard now.timeIntervalSince(lastPredictionTime) > 0.5 else { return }
        lastPredictionTime = now

        let predictions = YOLOPredictor.shared.predict(pixelBuffer: pixelBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.update(with: predictions)
        }
    }
}
