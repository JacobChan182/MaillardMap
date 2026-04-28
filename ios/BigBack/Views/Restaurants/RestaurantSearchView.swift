import SwiftUI

struct RestaurantSearchView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var vm = RestaurantSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    var onSelect: ((Restaurant) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search restaurants by name", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: vm.query) { _, _ in
                    vm.scheduleDebouncedSearch(near: mapVM.searchAnchor)
                }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.isLoading || vm.isAwaitingDebouncedSearch {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
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
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            Task {
                if !vm.query.isEmpty {
                    await vm.search(near: mapVM.searchAnchor)
                }
            }
        }
    }
}
