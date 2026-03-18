import SwiftUI
import AudioToolbox

struct SuccessCheckmarkView: View {
    @State private var circleProgress: CGFloat = 0
    @State private var checkmarkProgress: CGFloat = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 1

    var color: Color = .green
    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            // Background dim
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(opacity)

            VStack(spacing: 20) {
                ZStack {
                    // Circle stroke
                    Circle()
                        .trim(from: 0, to: circleProgress)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))

                    // Fill circle (appears after stroke completes)
                    Circle()
                        .fill(color.opacity(circleProgress >= 1 ? 0.15 : 0))
                        .frame(width: 90, height: 90)

                    // Checkmark
                    CheckmarkShape()
                        .trim(from: 0, to: checkmarkProgress)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 40, height: 40)
                }
                .scaleEffect(scale)

                Text("Done")
                    .font(.title3.bold())
                    .foregroundStyle(color)
                    .opacity(checkmarkProgress >= 1 ? 1 : 0)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        // Circle draws
        withAnimation(.easeInOut(duration: 0.4)) {
            circleProgress = 1
        }

        // Checkmark draws after circle
        withAnimation(.easeInOut(duration: 0.3).delay(0.35)) {
            checkmarkProgress = 1
        }

        // Bounce scale
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.6)) {
            scale = 1.15
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7).delay(0.75)) {
            scale = 1.0
        }

        // Haptic + sound at the checkmark moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // System "payment success" sound
            AudioServicesPlaySystemSound(1407)
        }

        // Fade out and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onComplete?()
        }
    }
}

// MARK: - Checkmark Path

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Matches Apple Pay style checkmark proportions
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.25))
        return path
    }
}
