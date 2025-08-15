import ARKit

func deviceSupportsLiDAR() -> Bool {
    // This checks if the device has a LiDAR sensor
    return ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
}
