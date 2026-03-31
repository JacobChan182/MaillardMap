import SwiftUI

struct RootView: View {
    @StateObject private var vm = RootViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("BigBack")
                    .font(.largeTitle.weight(.semibold))

                Text(vm.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Ping API /health") {
                    Task { await vm.pingHealth() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    RootView()
}

