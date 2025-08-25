import Foundation
import AVFoundation
import Vision
import Combine
import ImageIO

// TEMP: debugging toggles
private let USE_HEURISTICS  = true
private let USE_STABILIZER  = true




final class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let objectWillChange = ObservableObjectPublisher()
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput!
    private var lastPredictionTime: Date = .distantPast
    private let frameGap: TimeInterval = 0.20
    private weak var viewModel: DetectionViewModel?

    public func getSession() -> AVCaptureSession { session }

    func start(viewModel: DetectionViewModel) {
        self.viewModel = viewModel
        guard
          let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
          let input = try? AVCaptureDeviceInput(device: device)
        else { print("❌ Could not create AVCaptureDeviceInput"); return }

        self.input = input
        session.beginConfiguration()
        session.sessionPreset = .high
        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(0) { conn.videoRotationAngle = 0 }
            } else {
                if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
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
        Stabilizer.shared.reset()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        let now = Date()
        guard now.timeIntervalSince(lastPredictionTime) >= frameGap else { return }
        lastPredictionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let exif: CGImagePropertyOrientation
        if #available(iOS 17.0, *) {
            exif = exifFromRotationAngle(connection.videoRotationAngle, cameraPosition: .back)
        } else {
            exif = exifFromVideoOrientation(connection.videoOrientation, cameraPosition: .back)
        }

        // Run the selected detector
        let raw: [Prediction]
        switch ModeManager.shared.mode {
        case .ml:
            raw = CombinedPredictor.shared.predictTryingCrops(pixelBuffer: pixelBuffer, exifOrientation: exif)
        case .deterministic:
            raw = DeterministicDetector.shared.predict(pixelBuffer: pixelBuffer, exifOrientation: exif)
        }

        // Optional refinement/stabilization (your existing toggles)
        let refined = USE_HEURISTICS ? Heuristics.refine(predictions: raw) : raw
        let stable  = USE_STABILIZER ? Stabilizer.shared.update(with: refined) : refined

        if !raw.isEmpty {
            let cRaw = Dictionary(grouping: raw, by: { $0.label }).mapValues { $0.count }
            let cRef = Dictionary(grouping: refined, by: { $0.label }).mapValues { $0.count }
            let cSta = Dictionary(grouping: stable, by: { $0.label }).mapValues { $0.count }
            print("Counts raw:", cRaw, "refined:", cRef, "stable:", cSta)
        }

        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.update(with: stable)
        }

    }
}

@available(iOS 17.0, *)
private func exifFromRotationAngle(_ angle: CGFloat,
                                   cameraPosition: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
    switch Int(angle) % 360 {
    case 0: return .right
    case 90: return (cameraPosition == .front) ? .down : .up
    case 180: return .left
    case 270: return (cameraPosition == .front) ? .up : .down
    default: return .right
    }
}

@available(iOS, introduced: 13.0, deprecated: 17.0)
private func exifFromVideoOrientation(_ vo: AVCaptureVideoOrientation,
                                      cameraPosition: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
    switch vo {
    case .portrait: return .right
    case .portraitUpsideDown: return .left
    case .landscapeRight: return cameraPosition == .front ? .down : .up
    case .landscapeLeft: return cameraPosition == .front ? .up : .down
    @unknown default: return .right
    }
}
