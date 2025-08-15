import ARKit

func deviceSupportsLiDAR() -> Bool {
    // Check if the device has a LiDAR sensor
    return ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
}
