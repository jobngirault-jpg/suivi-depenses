import SwiftData
import SwiftUI

@main
struct ImmoPepiteApp: App {
    @State private var profileStore = InvestorProfileStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(profileStore)
        }
        .modelContainer(for: [FavoriteProperty.self, SavedSimulation.self])
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            PropertyListView()
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }

            SavedPropertiesView()
                .tabItem { Label("Mes biens", systemImage: "heart.fill") }
        }
        .tint(.orange)
    }
}

#Preview {
    RootTabView()
        .environment(InvestorProfileStore())
        .modelContainer(for: [FavoriteProperty.self, SavedSimulation.self], inMemory: true)
}
