import SwiftUI
import ARKit
import SceneKit

struct ARPreview: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.automaticallyUpdatesLighting = true
        v.session = session
        v.scene = SCNScene()
        return v
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // nothing to update per-frame here; ARSession is managed by LiDARService
    }
}
