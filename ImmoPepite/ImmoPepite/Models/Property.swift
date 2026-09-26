import Foundation

enum PropertyType: String, Codable, CaseIterable, Sendable {
    case apartment
    case house
    case building

    var label: String {
        switch self {
        case .apartment: "Appartement"
        case .house: "Maison"
        case .building: "Immeuble"
        }
    }

    var systemImage: String {
        switch self {
        case .apartment: "building.2"
        case .house: "house"
        case .building: "building.columns"
        }
    }
}

/// Annonce immobilière (domaine), indépendante du format de l'API.
struct Property: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var type: PropertyType
    /// Prix net vendeur (€).
    var price: Double
    /// Frais d'agence à la charge de l'acquéreur (€), 0 si prix FAI.
    var agencyFees: Double
    var surface: Double
    var rooms: Int
    var city: String
    var postalCode: String
    var departmentCode: String
    var imageURL: URL?
    var listingURL: URL?
    var summary: String
    var estimatedWorks: Double
    var estimatedMonthlyRent: Double
    var monthlyCondoFees: Double
    var annualPropertyTax: Double
    var condition: PropertyCondition
    /// Classe DPE (A à G).
    var energyClass: String?
    /// Commune éligible Denormandie (Action Cœur de Ville / ORT).
    var isDenormandieZone: Bool
    var source: String
    var publishedAt: Date

    var pricePerSquareMeter: Double {
        surface > 0 ? price / surface : 0
    }

    var locationLabel: String {
        "\(city) (\(postalCode))"
    }
}
