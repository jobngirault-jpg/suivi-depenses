import Foundation

/// Régimes fiscaux gérés par le moteur de calcul.
enum FiscalRegime: String, Codable, CaseIterable, Identifiable, Sendable {
    case lmnpReel
    case lmnpMicroBIC
    case foncierReel
    case microFoncier
    case sciIS
    case denormandie

    var id: Self { self }

    var label: String {
        switch self {
        case .lmnpReel: "LMNP Réel"
        case .lmnpMicroBIC: "LMNP Micro-BIC"
        case .foncierReel: "Nu – Foncier Réel"
        case .microFoncier: "Nu – Micro-Foncier"
        case .sciIS: "SCI à l'IS"
        case .denormandie: "Denormandie"
        }
    }

    var shortLabel: String {
        switch self {
        case .lmnpReel: "LMNP Réel"
        case .lmnpMicroBIC: "Micro-BIC"
        case .foncierReel: "Foncier Réel"
        case .microFoncier: "Micro-Foncier"
        case .sciIS: "SCI IS"
        case .denormandie: "Denormandie"
        }
    }

    var summary: String {
        switch self {
        case .lmnpReel:
            "Charges, intérêts et amortissements (bâti 30 ans, travaux 15 ans, mobilier 7 ans) déduits. Les amortissements ne créent pas de déficit : l'excédent est reporté sans limite."
        case .lmnpMicroBIC:
            "Abattement forfaitaire de 50 % sur les recettes (plafond 77 700 €). Aucune charge réelle déductible."
        case .foncierReel:
            "Location nue : charges, intérêts et travaux déductibles. Déficit foncier imputable sur le revenu global jusqu'à 10 700 €/an (hors intérêts), le reste est reporté 10 ans."
        case .microFoncier:
            "Location nue : abattement forfaitaire de 30 % (plafond 15 000 € de loyers)."
        case .sciIS:
            "Résultat soumis à l'IS (15 % jusqu'à 42 500 €, 25 % au-delà) après amortissements. Frais d'acquisition passés en charges l'année 1. Distribution de dividendes non modélisée."
        case .denormandie:
            "Location nue en zone éligible avec travaux ≥ 25 % du coût total : réduction d'impôt de 12/18/21 % (6/9/12 ans) sur 300 000 € max. Les travaux ouvrant droit à la réduction ne sont pas déductibles des revenus fonciers."
        }
    }

    /// Location meublée : le mobilier entre dans le coût de l'opération.
    var isFurnished: Bool {
        switch self {
        case .lmnpReel, .lmnpMicroBIC: true
        case .foncierReel, .microFoncier, .sciIS, .denormandie: false
        }
    }

    var requiresAccounting: Bool {
        self == .lmnpReel || self == .sciIS
    }
}

/// Durée d'engagement de location Denormandie.
enum DenormandieCommitment: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sixYears = 6
    case nineYears = 9
    case twelveYears = 12

    var id: Self { self }
    var label: String { "\(rawValue) ans" }

    /// Taux global de réduction d'impôt.
    var totalRate: Double {
        switch self {
        case .sixYears: 0.12
        case .nineYears: 0.18
        case .twelveYears: 0.21
        }
    }

    /// Taux annuel appliqué pour une année donnée (2 %/an jusqu'à 9 ans, puis 1 %/an de 10 à 12 ans).
    func annualRate(forYear year: Int) -> Double {
        guard year >= 1, year <= rawValue else { return 0 }
        return year <= 9 ? 0.02 : 0.01
    }
}
