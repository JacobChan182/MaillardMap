import SwiftUI

struct SavedPlacesView: View {
    @StateObject private var vm = SavedPlacesViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
            } else {
                List {
                    ForEach(vm.savedPlaces) { place in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(place.restaurant?.name ?? "Unknown")
                                    .font(.headline)
                                if let cuisine = place.restaurant?.cuisine {
                                    Text(cuisine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                Task { await vm.deletePlace(restaurantId: place.restaurantId) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    if vm.savedPlaces.isEmpty {
                        ContentUnavailableView(
                            "No saved places",
                            systemImage: "bookmark"
                        )
                    }
                }
            }
        }
        .refreshable { await vm.loadPlaces() }
        .task { await vm.loadPlaces() }
    }
}
