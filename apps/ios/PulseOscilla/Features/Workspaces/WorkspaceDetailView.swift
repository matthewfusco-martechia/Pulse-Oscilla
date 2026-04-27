import SwiftUI

struct WorkspaceDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tab.makeContentView(selectedTab: $selectedTab)
                }
                .tabItem { tab.label }
                .tag(tab)
            }
        }
    }
}
