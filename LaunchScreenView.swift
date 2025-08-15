import SwiftUI

struct LaunchScreenView: View {
    @State private var isActive = false

    var body: some View {
        Group {
            if isActive {
                ContentView()  // main app view
            } else {
                VStack(spacing: 20) {
                    Image("test_golf") // from your xcassets
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)

                    Text("Golf Hole Detector")
                        .font(.title)
                        .bold()
                        .foregroundColor(.green)

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
