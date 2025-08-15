import SwiftUI

@main
struct GolfAIApp: App {
    init() {
        let lidarAvailable = deviceSupportsLiDAR()
        print("🛰 LiDAR available: \(lidarAvailable)")
    }


    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
