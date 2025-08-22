import Foundation
import AVFoundation
import Vision
import Combine
import ImageIO   // CGImagePropertyOrientation

final class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - ObservableObject
    // We don’t actually publish any state yet, but @StateObject in ContentView
    // expects an ObservableObject. Supplying the publisher satisfies the protocol.
    let objectWillChange = ObservableObjectPublisher()

    // MARK: - Capture
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput!

    // simple throttle (~5 fps). Tweak or remove if you like.
    private var lastPredictionTime: Date = .distantPast
    private let frameGap: TimeInterval = 0.20

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

        // Orientation after adding the output
        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(0) {
                    conn.videoRotationAngle = 0    // portrait
                }
            } else {
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

        // throttle
        let now = Date()
        guard now.timeIntervalSince(lastPredictionTime) >= frameGap else { return }
        lastPredictionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Compute EXIF orientation for Vision based on iOS version
        let exif: CGImagePropertyOrientation
        if #available(iOS 17.0, *) {
            // 17+: we have a concrete rotation angle in degrees (0, 90, 180, 270)
            exif = exifFromRotationAngle(connection.videoRotationAngle, cameraPosition: .back)
        } else {
            // 16−: fall back to the old videoOrientation mapping
            exif = exifFromVideoOrientation(connection.videoOrientation, cameraPosition: .back)
        }

        // Run the model (Vision will handle resizing)
        let predictions = CombinedPredictor.shared.predictTryingCrops(pixelBuffer: pixelBuffer,
                                                                     exifOrientation: exif)


        if !predictions.isEmpty {
            print("Labels seen:", Set(predictions.map { $0.label }))
        }

        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.update(with: predictions)
        }
    }
}

// MARK: - EXIF helpers

@available(iOS 17.0, *)
private func exifFromRotationAngle(_ angle: CGFloat,
                                   cameraPosition: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
    // angle is usually 0, 90, 180, 270 (clockwise)
    switch Int(angle) % 360 {
    case 0:    // portrait
        return .right
    case 90:   // landscapeRight
        // Home/bottom on the right
        return (cameraPosition == .front) ? .down : .up
    case 180:  // portraitUpsideDown
        return .left
    case 270:  // landscapeLeft
        // Home/bottom on the left
        return (cameraPosition == .front) ? .up : .down
    default:
        return .right
    }
}

@available(iOS, introduced: 13.0, deprecated: 17.0)
private func exifFromVideoOrientation(_ vo: AVCaptureVideoOrientation,
                                      cameraPosition: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
    switch vo {
    case .portrait:
        return .right
    case .portraitUpsideDown:
        return .left
    case .landscapeRight:
        // Home/bottom on the right
        return cameraPosition == .front ? .down : .up
    case .landscapeLeft:
        // Home/bottom on the left
        return cameraPosition == .front ? .up : .down
    @unknown default:
        return .right
    }
}

