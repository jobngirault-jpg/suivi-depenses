import Foundation
import Observation

/// Annonce enrichie de sa simulation selon le profil investisseur.
struct PropertyListItem: Identifiable, Hashable, Sendable {
    let property: Property
    let result: SimulationResult

    var id: String { property.id }
}

enum PropertySortOption: String, CaseIterable, Identifiable, Sendable {
    case cashflow
    case grossYield
    case priceAscending
    case newest

    var id: Self { self }

    var label: String {
        switch self {
        case .cashflow: "Cash-flow net-net"
        case .grossYield: "Rendement brut"
        case .priceAscending: "Prix croissant"
        case .newest: "Plus récentes"
        }
    }
}

@Observable
@MainActor
final class PropertyListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var properties: [Property] = []
    private(set) var state: LoadState = .idle
    var filter = SearchFilter()
    var sortOption: PropertySortOption = .cashflow

    private let service: any PropertyProviding

    init(service: any PropertyProviding = PropertyServiceFactory.makeDefault()) {
        self.service = service
    }

    // MARK: Chargement

    func load() async {
        state = .loading
        do {
            properties = try await service.fetchProperties(filter: filter)
            state = .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func apply(filter newFilter: SearchFilter) async {
        let needsReload = newFilter.departmentCodes != filter.departmentCodes
            || newFilter.postalCodes != filter.postalCodes
            || newFilter.maxPrice != filter.maxPrice
        filter = newFilter
        if needsReload {
            await load()
        }
    }

    func removeDepartment(_ code: String) async {
        var updated = filter
        updated.toggleDepartment(code)
        await apply(filter: updated)
    }

    func removePostalCode(_ postalCode: String) async {
        var updated = filter
        updated.togglePostalCode(postalCode)
        await apply(filter: updated)
    }

    // MARK: Résultats

    /// Simule chaque annonce avec le profil courant, puis applique filtres financiers et tri.
    func items(for profile: InvestorProfile) -> [PropertyListItem] {
        let items = properties.compactMap { property -> PropertyListItem? in
            let result = FinancialEngine.simulate(.make(for: property, profile: profile))
            guard filter.matches(property, result: result) else { return nil }
            return PropertyListItem(property: property, result: result)
        }

        return items.sorted { lhs, rhs in
            switch sortOption {
            case .cashflow: lhs.result.monthlyNetNetCashflow > rhs.result.monthlyNetNetCashflow
            case .grossYield: lhs.result.grossYield > rhs.result.grossYield
            case .priceAscending: lhs.property.price < rhs.property.price
            case .newest: lhs.property.publishedAt > rhs.property.publishedAt
            }
        }
    }
}
