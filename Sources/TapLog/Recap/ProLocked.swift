import SwiftUI

/// Non-functional Pro gate. Real purchases (StoreKit 2) land after the prototype.
struct ProLocked: View {
    let feature: String

    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(feature)
                .font(.headline)
            Text("This is a TapLog Pro feature.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Learn more") { showingInfo = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showingInfo) {
            VStack(spacing: 16) {
                Text("TapLog Pro")
                    .font(.title2.bold())
                Text("Weekly recaps, CSV export, and more are coming in the first paid release. This is a prototype — no purchases are wired up yet.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close") { showingInfo = false }
                    .buttonStyle(.bordered)
            }
            .padding(32)
            .presentationDetents([.medium])
        }
    }
}
