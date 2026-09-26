import Foundation

/// Hypothèses de financement et de fiscalité de l'investisseur, appliquées au scoring des annonces.
struct InvestorProfile: Codable, Hashable, Sendable {
    /// Apport en fraction du coût total de l'opération.
    var downPaymentRate = 0.10
    var loanRate = 0.034
    var loanDurationYears = 25
    var insuranceRate = 0.0030
    var marginalTaxRate = 0.30
    var preferredRegime: FiscalRegime = .lmnpReel
    var managementFeeRate = 0.0
    var vacancyRate = 0.05
    var annualPNOInsurance = 150.0
    var furnitureBudget = 5_000.0

    static let `default` = InvestorProfile()
    static let loanDurations = [15, 20, 25]
}

extension SimulationInput {
    /// Construit une simulation initiale à partir d'une annonce et du profil investisseur.
    static func make(for property: Property, profile: InvestorProfile, regime: FiscalRegime? = nil) -> SimulationInput {
        let regime = regime ?? profile.preferredRegime
        let acquisition = AcquisitionInput(
            purchasePrice: property.price,
            agencyFees: property.agencyFees,
            surface: property.surface,
            worksMode: .fixedAmount,
            worksAmount: property.estimatedWorks,
            worksPerSquareMeter: property.surface > 0 ? (property.estimatedWorks / property.surface).rounded() : 0,
            condition: property.condition,
            notaryFeesOverride: nil,
            furnitureAmount: profile.furnitureBudget
        )

        var input = SimulationInput(
            acquisition: acquisition,
            financing: FinancingInput(
                downPayment: 0,
                annualRate: profile.loanRate,
                durationYears: profile.loanDurationYears,
                insuranceRate: profile.insuranceRate
            ),
            operation: OperationInput(
                monthlyRent: property.estimatedMonthlyRent,
                monthlyCondoFees: property.monthlyCondoFees,
                annualPropertyTax: property.annualPropertyTax,
                managementFeeRate: profile.managementFeeRate,
                vacancyRate: profile.vacancyRate,
                annualPNOInsurance: profile.annualPNOInsurance
            ),
            taxation: TaxationInput(
                regime: regime,
                marginalTaxRate: profile.marginalTaxRate,
                isDenormandieZone: property.isDenormandieZone
            )
        )
        input.financing.downPayment = (input.totalProjectCost * profile.downPaymentRate / 100).rounded() * 100
        return input
    }
}
