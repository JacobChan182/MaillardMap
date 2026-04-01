import SwiftUI

/// Shared list cell for restaurant search (Find + post picker).
struct RestaurantSearchResultRow: View {
    let restaurant: Restaurant

    var body: some View {
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
    }
}
