import SwiftUI

struct RestaurantSearchView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var vm = RestaurantSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    var onSelect: ((Restaurant) -> Void)?

    var body: some View {
        VStack {
            TextField("Search restaurants by name", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: vm.query) { _, _ in
                    Task { await vm.search(near: mapVM.searchAnchor) }
                }

            if vm.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.results) { restaurant in
                            RestaurantSearchResultRow(restaurant: restaurant)
                                .onTapGesture {
                                    vm.selectedRestaurant = restaurant
                                    if let onSelect = onSelect {
                                        onSelect(restaurant)
                                        dismiss()
                                    } else {
                                        mapVM.focusRestaurantFromSearch(restaurant)
                                        tabRouter.openMap()
                                        dismiss()
                                    }
                                }
                        }

                        if vm.results.isEmpty && !vm.query.isEmpty {
                            Text("No restaurants found")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            Task {
                if !vm.query.isEmpty {
                    await vm.search(near: mapVM.searchAnchor)
                }
            }
        }
        .onChange(of: mapVM.userLocation?.latitude) { _, _ in
            guard !vm.query.isEmpty else { return }
            Task { await vm.search(near: mapVM.searchAnchor) }
        }
    }
}
