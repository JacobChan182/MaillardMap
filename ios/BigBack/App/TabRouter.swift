import Foundation

@MainActor
final class TabRouter: ObservableObject {
    enum Tab: Int {
        case feed = 0
        case map = 1
        case create = 2
        case blend = 3
        case more = 4
    }

    @Published var selectedTab: Int = Tab.feed.rawValue

    func openMap() {
        selectedTab = Tab.map.rawValue
    }
}
