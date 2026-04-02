import SwiftUI

struct RestaurantPickerSheet: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @StateObject private var searchVM = RestaurantSearchViewModel()
    var onSelect: (Restaurant) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search restaurants by name", text: $searchVM.query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchVM.query) { _, _ in
                        searchVM.scheduleDebouncedSearch(near: mapVM.searchAnchor)
                    }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if searchVM.isLoading || searchVM.isAwaitingDebouncedSearch {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(searchVM.results) { restaurant in
                                Button {
                                    onSelect(restaurant)
                                } label: {
                                    RestaurantSearchResultRow(restaurant: restaurant)
                                }
                                .buttonStyle(.plain)
                            }

                            if searchVM.results.isEmpty && !searchVM.query.isEmpty {
                                Text("No restaurants found")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
