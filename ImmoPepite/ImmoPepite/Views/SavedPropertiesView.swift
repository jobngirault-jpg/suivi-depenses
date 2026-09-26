import SwiftData
import SwiftUI

struct SavedPropertiesView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case favorites = "Favoris"
        case simulations = "Simulations"

        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(InvestorProfileStore.self) private var profileStore

    @Query(sort: \FavoriteProperty.addedAt, order: .reverse) private var favorites: [FavoriteProperty]
    @Query(sort: \SavedSimulation.createdAt, order: .reverse) private var simulations: [SavedSimulation]

    @State private var segment: Segment = .favorites

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Affichage", selection: $segment) {
                        ForEach(Segment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch segment {
                case .favorites: favoritesSection
                case .simulations: simulationsSection
                }
            }
            .navigationTitle("Mes biens")
            .overlay { emptyState }
        }
    }

    // MARK: Favoris

    @ViewBuilder
    private var favoritesSection: some View {
        Section {
            ForEach(favorites) { favorite in
                if let property = favorite.property {
                    NavigationLink {
                        PropertyDetailView(property: property, profile: profileStore.profile)
                    } label: {
                        FavoriteRow(property: property, result: simulate(property))
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { favorites[$0] }.forEach { modelContext.delete($0) }
            }
        }
    }

    // MARK: Simulations

    @ViewBuilder
    private var simulationsSection: some View {
        Section {
            ForEach(simulations) { simulation in
                if let property = simulation.property, let input = simulation.input {
                    NavigationLink {
                        PropertyDetailView(
                            property: property,
                            profile: profileStore.profile,
                            input: input,
                            savedSimulationID: simulation.id
                        )
                    } label: {
                        SimulationRow(simulation: simulation)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { simulations[$0] }.forEach { modelContext.delete($0) }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch segment {
        case .favorites where favorites.isEmpty:
            ContentUnavailableView(
                "Aucun favori",
                systemImage: "heart",
                description: Text("Touchez le cœur d'une annonce pour la retrouver ici.")
            )
        case .simulations where simulations.isEmpty:
            ContentUnavailableView(
                "Aucune simulation",
                systemImage: "slider.horizontal.3",
                description: Text("Ajustez les curseurs d'un bien puis enregistrez votre scénario.")
            )
        default:
            EmptyView()
        }
    }

    private func simulate(_ property: Property) -> SimulationResult {
        FinancialEngine.simulate(.make(for: property, profile: profileStore.profile))
    }
}

// MARK: - Lignes

private struct FavoriteRow: View {
    let property: Property
    let result: SimulationResult

    var body: some View {
        HStack(spacing: 12) {
            PropertyImageView(url: property.imageURL, type: property.type)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(property.price.euros).font(.headline)
                    if result.isPepite {
                        PepiteBadge().scaleEffect(0.8)
                    }
                }
                Text(property.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(property.locationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("CF net-net \(result.monthlyNetNetCashflow.signedEuros)/mois · \(result.grossYield.percent) brut")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(result.monthlyNetNetCashflow.cashflowColor)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SimulationRow: View {
    let simulation: SavedSimulation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(simulation.name)
                .font(.headline)
            Text(simulation.propertyTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack {
                Text(simulation.regime?.shortLabel ?? "—")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                Text("\(simulation.monthlyNetNetCashflow.signedEuros)/mois")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(simulation.monthlyNetNetCashflow.cashflowColor)
                Text("· \(simulation.grossYield.percent) brut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(simulation.createdAt, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
