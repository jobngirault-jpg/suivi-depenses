import Foundation
import SwiftData

/// Simulation financière personnalisée enregistrée par l'utilisateur.
@Model
final class SavedSimulation {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var propertyID: String
    var propertyTitle: String
    var regimeRawValue: String
    var monthlyNetNetCashflow: Double
    var grossYield: Double
    var propertyPayload: Data
    var inputPayload: Data

    init(name: String, property: Property, input: SimulationInput, result: SimulationResult, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.propertyID = property.id
        self.propertyTitle = property.title
        self.regimeRawValue = input.taxation.regime.rawValue
        self.monthlyNetNetCashflow = result.monthlyNetNetCashflow
        self.grossYield = result.grossYield
        self.propertyPayload = (try? JSONEncoder().encode(property)) ?? Data()
        self.inputPayload = (try? JSONEncoder().encode(input)) ?? Data()
    }

    var regime: FiscalRegime? { FiscalRegime(rawValue: regimeRawValue) }

    var property: Property? {
        try? JSONDecoder().decode(Property.self, from: propertyPayload)
    }

    var input: SimulationInput? {
        try? JSONDecoder().decode(SimulationInput.self, from: inputPayload)
    }

    func update(input: SimulationInput, result: SimulationResult) {
        regimeRawValue = input.taxation.regime.rawValue
        monthlyNetNetCashflow = result.monthlyNetNetCashflow
        grossYield = result.grossYield
        inputPayload = (try? JSONEncoder().encode(input)) ?? inputPayload
    }
}
