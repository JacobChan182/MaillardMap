import SwiftUI

struct RestaurantSearchView: View {
    @StateObject private var vm = RestaurantSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    var onSelect: ((Restaurant) -> Void)?

    var body: some View {
        VStack {
            TextField("Search restaurants by name", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: vm.query) { _, _ in
                    Task { await vm.search() }
                }

            if vm.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.results) { restaurant in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant.name)
                                    .font(.headline)
                                if let cuisine = restaurant.cuisine {
                                    Text(cuisine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let address = restaurant.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(10)
                            .onTapGesture {
                                vm.selectedRestaurant = restaurant
                                if let onSelect = onSelect {
                                    onSelect(restaurant)
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
    }
}
