import Foundation
import Observation

struct RegimeComparison: Identifiable, Hashable, Sendable {
    let regime: FiscalRegime
    let monthlyNetNetCashflow: Double

    var id: FiscalRegime { regime }
}

/// Simulation interactive d'un bien : chaque modification de `input` recalcule `result`.
@Observable
@MainActor
final class PropertyDetailViewModel {
    let property: Property
    var input: SimulationInput {
        didSet { result = FinancialEngine.simulate(input) }
    }
    private(set) var result: SimulationResult

    /// Simulation enregistrée en cours d'édition (le cas échéant).
    let savedSimulationID: UUID?

    init(property: Property, profile: InvestorProfile, input: SimulationInput? = nil, savedSimulationID: UUID? = nil) {
        let initialInput = input ?? .make(for: property, profile: profile)
        self.property = property
        self.input = initialInput
        self.result = FinancialEngine.simulate(initialInput)
        self.savedSimulationID = savedSimulationID
    }

    // MARK: Bornes des curseurs

    var priceRange: ClosedRange<Double> {
        let floor = (property.price * 0.6 / 1_000).rounded(.down) * 1_000
        let ceiling = (property.price * 1.1 / 1_000).rounded(.up) * 1_000
        return floor...max(ceiling, floor + 1_000)
    }

    var worksRange: ClosedRange<Double> {
        let ceiling = max(property.estimatedWorks * 2, property.price * 0.6, 20_000)
        return 0...(ceiling / 1_000).rounded(.up) * 1_000
    }

    var worksPerSquareMeterRange: ClosedRange<Double> { 0...1_500 }

    var rentRange: ClosedRange<Double> {
        let floor = (property.estimatedMonthlyRent * 0.5 / 10).rounded(.down) * 10
        let ceiling = (property.estimatedMonthlyRent * 1.5 / 10).rounded(.up) * 10
        return floor...max(ceiling, floor + 10)
    }

    var downPaymentRange: ClosedRange<Double> {
        0...max((input.totalProjectCost / 1_000).rounded(.up) * 1_000, 1_000)
    }

    /// Négociation par rapport au prix affiché (fraction négative = remise).
    var negotiationRate: Double {
        property.price > 0 ? input.acquisition.purchasePrice / property.price - 1 : 0
    }

    // MARK: Actions

    func resetToListing(profile: InvestorProfile) {
        input = .make(for: property, profile: profile, regime: input.taxation.regime)
    }

    /// Compare le cash-flow net-net de tous les régimes pour la configuration courante.
    func regimeComparison() -> [RegimeComparison] {
        FiscalRegime.allCases.map { regime in
            var variant = input
            variant.taxation.regime = regime
            return RegimeComparison(regime: regime, monthlyNetNetCashflow: FinancialEngine.simulate(variant).monthlyNetNetCashflow)
        }
    }
}
