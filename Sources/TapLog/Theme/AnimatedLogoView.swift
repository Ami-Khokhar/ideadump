import SwiftUI

/// The animated logo shown on app launch — smooth materialise + breathing pulse + ripple rings.
struct AnimatedLogoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var showText = false
    @State private var ripplePhase: Double = 0
    @State private var logoVisible = false

    var body: some View {
        VStack(spacing: 18) {
            // Logo with ripples expanding from its center
            ZStack {
                rippleRings
                    .allowsHitTesting(false)

                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(breathe ? 1.0 : 0.85)
                    .blur(radius: logoVisible ? 0 : 6)
                    .opacity(breathe ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.7).delay(0.15),
                        value: breathe
                    )
                    // Continuous subtle breathing after entrance
                    .scaleEffect(breathe ? breatheScale : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.0),
                        value: breathe
                    )
            }
            // Let the ripples extend beyond the logo frame
            .frame(width: 200, height: 200)

            Text("TapLog")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .offset(y: showText ? 0 : 8)
                .opacity(showText ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.05), value: showText)
        }
        .onAppear {
            if reduceMotion {
                logoVisible = true
                breathe = true
                showText = true
                ripplePhase = 1
            } else {
                withAnimation(.easeOut(duration: 0.4)) { logoVisible = true }
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.15)) { breathe = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showText = true }
                startRipples()
            }
        }
    }

    /// Subtle continuous breathing scale (0.98 ↔ 1.02) after the entrance settles.
    private var breatheScale: CGFloat {
        breathe ? 1.02 : 1.0
    }

    /// 3 concentric ripple rings expanding outward from the logo center.
    private var rippleRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let delay = Double(i) * 1.2
                Circle()
                    .stroke(Theme.accent.opacity(0.10))
                    .frame(width: 80 + ripplePhase * 130, height: 80 + ripplePhase * 130)
                    .opacity(max(0, 1 - ripplePhase))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 3.5).delay(delay).repeatForever(autoreverses: false),
                        value: ripplePhase
                    )
            }
        }
    }

    private func startRipples() {
        withAnimation { ripplePhase = 1.0 }
    }
}
