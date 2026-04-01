import SwiftUI

struct RestaurantPickerSheet: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @StateObject private var searchVM = RestaurantSearchViewModel()
    var onSelect: (Restaurant) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search restaurants...", text: $searchVM.query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchVM.query) { _, _ in
                        Task { await searchVM.search(near: mapVM.searchAnchor) }
                    }

                if searchVM.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(searchVM.results) { restaurant in
                                Button {
                                    onSelect(restaurant)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(restaurant.name)
                                                .font(.headline)
                                            if let cuisine = restaurant.cuisine {
                                                Text(cuisine)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }

                            if searchVM.results.isEmpty && !searchVM.query.isEmpty {
                                Text("No restaurants found")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Choose Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Presented as sheet, dismiss handled by parent
                    }
                }
            }
            .onAppear {
                Task {
                    if !searchVM.query.isEmpty {
                        await searchVM.search(near: mapVM.searchAnchor)
                    }
                }
            }
            .onChange(of: mapVM.userLocation?.latitude) { _, _ in
                guard !searchVM.query.isEmpty else { return }
                Task { await searchVM.search(near: mapVM.searchAnchor) }
            }
        }
    }
}
