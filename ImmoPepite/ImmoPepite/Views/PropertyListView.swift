import SwiftData
import SwiftUI

struct PropertyListView: View {
    @Environment(InvestorProfileStore.self) private var profileStore
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteProperty]

    @State private var viewModel = PropertyListViewModel()
    @State private var isShowingFilters = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ImmoPépite")
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .top, spacing: 0) { activeFiltersBar }
                .sheet(isPresented: $isShowingFilters) {
                    FilterView(filter: viewModel.filter) { newFilter in
                        Task { await viewModel.apply(filter: newFilter) }
                    }
                }
                .navigationDestination(for: Property.self) { property in
                    PropertyDetailView(property: property, profile: profileStore.profile)
                }
                .task {
                    if viewModel.state == .idle {
                        await viewModel.load()
                    }
                }
                .refreshable { await viewModel.load() }
        }
    }

    // MARK: Contenu

    @ViewBuilder
    private var content: some View {
        let items = viewModel.items(for: profileStore.profile)

        switch viewModel.state {
        case .idle, .loading where viewModel.properties.isEmpty:
            ProgressView("Recherche des annonces…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Chargement impossible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Réessayer") { Task { await viewModel.load() } }
                    .buttonStyle(.borderedProminent)
            }
        default:
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Aucune annonce", systemImage: "magnifyingglass")
                } description: {
                    Text("Aucun bien ne correspond à vos critères. Élargissez la zone ou assouplissez les seuils de rendement et de cash-flow.")
                } actions: {
                    Button("Modifier les filtres") { isShowingFilters = true }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        summaryHeader(items: items)
                        ForEach(items) { item in
                            NavigationLink(value: item.property) {
                                PropertyCardView(
                                    item: item,
                                    isFavorite: isFavorite(item.property),
                                    onToggleFavorite: { toggleFavorite(item.property) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func summaryHeader(items: [PropertyListItem]) -> some View {
        let pepites = items.filter(\.result.isPepite).count
        return HStack {
            Text("\(items.count) bien\(items.count > 1 ? "s" : "")")
                .font(.subheadline.weight(.semibold))
            if pepites > 0 {
                Text("· \(pepites) pépite\(pepites > 1 ? "s" : "")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text(profileStore.profile.preferredRegime.shortLabel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
        .padding(.top, 8)
    }

    // MARK: Filtres actifs

    @ViewBuilder
    private var activeFiltersBar: some View {
        let filter = viewModel.filter
        if !filter.departmentCodes.isEmpty || !filter.postalCodes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filter.departmentCodes.sorted(), id: \.self) { code in
                        ChipView(
                            title: DepartmentCatalog.department(code: code)?.label ?? code,
                            isSelected: true,
                            showsRemoveIcon: true
                        ) {
                            Task { await viewModel.removeDepartment(code) }
                        }
                    }
                    ForEach(filter.postalCodes.sorted(), id: \.self) { postalCode in
                        ChipView(
                            title: DepartmentCatalog.city(postalCode: postalCode)?.label ?? postalCode,
                            showsRemoveIcon: true
                        ) {
                            Task { await viewModel.removePostalCode(postalCode) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Trier par", selection: $viewModel.sortOption) {
                    ForEach(PropertySortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } label: {
                Label("Trier", systemImage: "arrow.up.arrow.down")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingFilters = true
            } label: {
                Label("Filtres", systemImage: viewModel.filter.activeCriteriaCount > 0
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
        }
    }

    // MARK: Favoris

    private func isFavorite(_ property: Property) -> Bool {
        favorites.contains { $0.propertyID == property.id }
    }

    private func toggleFavorite(_ property: Property) {
        if let existing = favorites.first(where: { $0.propertyID == property.id }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteProperty(property: property))
        }
    }
}
