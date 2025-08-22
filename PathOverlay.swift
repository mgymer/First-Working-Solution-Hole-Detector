import SwiftUI
import CoreGraphics

struct PathOverlay: View {
    let ball: CGPoint
    let hole: CGPoint
    let downhillFromBall: CGVector?

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: ball)
                p.addLine(to: hole)
            }
            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [10,6]))
            .foregroundColor(.white)
            if let v = downhillFromBall {
                let d = hypot(hole.x - ball.x, hole.y - ball.y)
                let k = max(40.0, min(0.6 * d, 220.0))
                let cp = CGPoint(x: ball.x + v.dx * k, y: ball.y + v.dy * k)
                Path { p in
                    p.move(to: ball)
                    p.addQuadCurve(to: hole, control: cp)
                }
                .stroke(Color.yellow, lineWidth: 4)
                .shadow(radius: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
