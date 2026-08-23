import SwiftUI

/// The animated logo shown on app launch — breathing scale + ripple rings expanding outward.
struct AnimatedLogoView: View {
    @State private var breathe = false
    @State private var showText = false
    @State private var ripplePhase: Double = 0

    var body: some View {
        ZStack {
            // Ripple rings expanding from behind the logo
            rippleRings

            // Logo + text
            VStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(breathe ? 1.0 : 0.92)
                    .opacity(breathe ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: breathe)

                Text("TapLog")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: showText)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { breathe = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showText = true }
            // Continuous ripple animation
            startRipples()
        }
    }

    /// 3 concentric ripple rings that expand outward.
    private var rippleRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let delay = Double(i) * 1.0
                Circle()
                    .stroke(Theme.accent.opacity(0.10))
                    .frame(width: 80 + ripplePhase * 120, height: 80 + ripplePhase * 120)
                    .opacity(max(0, 1 - ripplePhase))
                    .animation(
                        .easeOut(duration: 3.0).delay(delay).repeatForever(autoreverses: false),
                        value: ripplePhase
                    )
            }
        }
        .frame(width: 300, height: 300)
    }

    private func startRipples() {
        // Kick the ripple animation
        withAnimation { ripplePhase = 1.0 }
    }
}
