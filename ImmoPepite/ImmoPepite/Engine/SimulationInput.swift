import Foundation

/// État du bien : conditionne l'estimation automatique des frais de notaire.
enum PropertyCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case old
    case new

    var id: Self { self }

    var label: String {
        switch self {
        case .old: "Ancien"
        case .new: "Neuf / VEFA"
        }
    }

    var notaryRate: Double {
        switch self {
        case .old: FiscalConstants.notaryRateOld
        case .new: FiscalConstants.notaryRateNew
        }
    }
}

enum WorksMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixedAmount
    case perSquareMeter

    var id: Self { self }

    var label: String {
        switch self {
        case .fixedAmount: "Montant fixe"
        case .perSquareMeter: "€ / m²"
        }
    }
}

// MARK: - Acquisition

struct AcquisitionInput: Codable, Hashable, Sendable {
    /// Prix net vendeur (€).
    var purchasePrice: Double
    /// Frais d'agence à la charge de l'acquéreur (€).
    var agencyFees: Double
    var surface: Double
    var worksMode: WorksMode
    /// Montant des travaux si `worksMode == .fixedAmount` (€).
    var worksAmount: Double
    /// Coût des travaux au m² si `worksMode == .perSquareMeter` (€/m²).
    var worksPerSquareMeter: Double
    var condition: PropertyCondition
    /// Frais de notaire saisis manuellement ; `nil` = estimation automatique.
    var notaryFeesOverride: Double?
    /// Budget mobilier (pris en compte uniquement pour les régimes meublés).
    var furnitureAmount: Double

    var worksTotal: Double {
        switch worksMode {
        case .fixedAmount: max(worksAmount, 0)
        case .perSquareMeter: max(worksPerSquareMeter * surface, 0)
        }
    }

    /// Frais de notaire : assiette = prix net vendeur (hors frais d'agence).
    var notaryFees: Double {
        notaryFeesOverride ?? (purchasePrice * condition.notaryRate).rounded()
    }
}

// MARK: - Financement

struct FinancingInput: Codable, Hashable, Sendable {
    /// Apport personnel (€).
    var downPayment: Double
    /// Taux nominal annuel (fraction : 0.034 = 3,4 %).
    var annualRate: Double
    var durationYears: Int
    /// Taux annuel d'assurance emprunteur appliqué au capital initial (fraction).
    var insuranceRate: Double
}

// MARK: - Exploitation

struct OperationInput: Codable, Hashable, Sendable {
    /// Loyer mensuel hors charges estimé (€).
    var monthlyRent: Double
    /// Charges de copropriété non récupérables (€/mois).
    var monthlyCondoFees: Double
    /// Taxe foncière annuelle (€).
    var annualPropertyTax: Double
    /// Frais de gestion locative (fraction des loyers encaissés).
    var managementFeeRate: Double
    /// Vacance locative (fraction de l'année).
    var vacancyRate: Double
    /// Assurance propriétaire non occupant (€/an).
    var annualPNOInsurance: Double
}

// MARK: - Fiscalité

struct TaxationInput: Codable, Hashable, Sendable {
    var regime: FiscalRegime
    /// Tranche marginale d'imposition du foyer (fraction).
    var marginalTaxRate: Double
    var socialContributionsRate: Double = FiscalConstants.socialContributionsRate
    /// Quote-part terrain non amortissable (fraction du prix).
    var landShare: Double = FiscalConstants.defaultLandShare
    /// Honoraires expert-comptable LMNP réel (€/an).
    var lmnpAccountingFees: Double = 500
    /// Honoraires comptables + frais juridiques SCI (€/an).
    var sciAccountingFees: Double = 1_200
    var denormandieCommitment: DenormandieCommitment = .twelveYears
    /// Commune éligible (programme Action Cœur de Ville / ORT).
    var isDenormandieZone: Bool = false
    /// Horizon de projection utilisé pour lisser les effets fiscaux (années).
    var projectionYears: Int = 10

    func accountingFees(for regime: FiscalRegime) -> Double {
        switch regime {
        case .lmnpReel: lmnpAccountingFees
        case .sciIS: sciAccountingFees
        default: 0
        }
    }
}

// MARK: - Entrée complète

struct SimulationInput: Codable, Hashable, Sendable {
    var acquisition: AcquisitionInput
    var financing: FinancingInput
    var operation: OperationInput
    var taxation: TaxationInput

    /// Coût total de l'opération pour le régime courant (hors apport).
    var totalProjectCost: Double {
        let furniture = taxation.regime.isFurnished ? acquisition.furnitureAmount : 0
        return acquisition.purchasePrice + acquisition.agencyFees + acquisition.notaryFees
            + acquisition.worksTotal + furniture
    }
}
