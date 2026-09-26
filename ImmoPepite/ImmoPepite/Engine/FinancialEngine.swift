import Foundation

/// Moteur de calcul financier et fiscal pur (sans état, sans dépendance UI).
///
/// Conventions :
/// - tous les taux sont exprimés en fractions (0.034 = 3,4 %) ;
/// - les rendements sont calculés sur le coût total de l'opération (prix + frais + travaux + mobilier) ;
/// - le cash-flow net-net est lissé sur `taxation.projectionYears` afin de ne pas surpondérer
///   les effets fiscaux ponctuels de l'année 1 (déficit foncier, frais d'acquisition en SCI IS).
enum FinancialEngine {
    static func simulate(_ input: SimulationInput) -> SimulationResult {
        let acquisition = input.acquisition
        let financing = input.financing
        let operation = input.operation
        let taxation = input.taxation
        let regime = taxation.regime

        // MARK: Coût de l'opération
        let costs = CostBreakdown(
            purchasePrice: max(acquisition.purchasePrice, 0),
            agencyFees: max(acquisition.agencyFees, 0),
            notaryFees: max(acquisition.notaryFees, 0),
            works: acquisition.worksTotal,
            furniture: regime.isFurnished ? max(acquisition.furnitureAmount, 0) : 0
        )
        let totalCost = costs.total
        let downPayment = min(max(financing.downPayment, 0), totalCost)
        let loanAmount = max(totalCost - downPayment, 0)

        // MARK: Crédit
        let loan = LoanCalculator.schedule(
            principal: loanAmount,
            annualRate: max(financing.annualRate, 0),
            durationYears: max(financing.durationYears, 1),
            annualInsuranceRate: max(financing.insuranceRate, 0)
        )
        let monthlyTotalLoan = loan.monthlyPayment + loan.monthlyInsurance

        // MARK: Exploitation
        let vacancy = min(max(operation.vacancyRate, 0), 1)
        let annualGrossRent = max(operation.monthlyRent, 0) * 12
        let rentCollected = annualGrossRent * (1 - vacancy)
        let managementFees = rentCollected * max(operation.managementFeeRate, 0)
        let operatingCharges = operation.monthlyCondoFees * 12
            + operation.annualPropertyTax
            + managementFees
            + operation.annualPNOInsurance
            + taxation.accountingFees(for: regime)
        let netOperatingIncome = rentCollected - operatingCharges

        let grossYield = totalCost > 0 ? annualGrossRent / totalCost : 0
        let netYield = totalCost > 0 ? netOperatingIncome / totalCost : 0

        // MARK: Fiscalité & projection
        let isDenormandieEligible = taxation.isDenormandieZone
            && totalCost > 0
            && costs.works >= FiscalConstants.denormandieMinimumWorksRatio * (totalCost - costs.furniture)

        let context = TaxContext(
            regime: regime,
            rentCollected: rentCollected,
            operatingCharges: operatingCharges,
            purchasePrice: costs.purchasePrice,
            agencyFees: costs.agencyFees,
            notaryFees: costs.notaryFees,
            works: costs.works,
            furniture: costs.furniture,
            landShare: min(max(taxation.landShare, 0), 1),
            marginalTaxRate: taxation.marginalTaxRate,
            socialContributionsRate: taxation.socialContributionsRate,
            denormandieCommitment: taxation.denormandieCommitment,
            isDenormandieEligible: isDenormandieEligible
        )

        let horizon = max(taxation.projectionYears, 1)
        var carry = TaxCarryState()
        var projections: [YearlyProjection] = []
        projections.reserveCapacity(horizon)

        for year in 1...horizon {
            let loanYear = loan.year(year)
            let tax = TaxCalculator.compute(year: year, context: context, loan: loanYear, state: &carry)
            projections.append(YearlyProjection(
                year: year,
                rentCollected: rentCollected,
                operatingCharges: operatingCharges,
                loanInterest: loanYear.interest,
                loanInsurance: loanYear.insurance,
                principalRepaid: loanYear.principal,
                remainingPrincipal: loanYear.remainingPrincipal,
                taxableIncome: tax.taxableIncome,
                incomeTax: tax.incomeTax,
                socialContributions: tax.socialContributions,
                corporateTax: tax.corporateTax,
                deficitTaxSaving: tax.deficitTaxSaving,
                taxReduction: tax.taxReduction
            ))
        }

        let averageAnnualCashflowAfterTax = projections.reduce(0) { $0 + $1.cashflowAfterTax } / Double(horizon)
        let averageAnnualTax = projections.reduce(0) { $0 + $1.netTax } / Double(horizon)

        return SimulationResult(
            costs: costs,
            downPayment: downPayment,
            loanAmount: loanAmount,
            monthlyLoanPayment: loan.monthlyPayment,
            monthlyLoanInsurance: loan.monthlyInsurance,
            totalInterest: loan.totalInterest,
            totalInsurance: loan.totalInsurance,
            grossYield: grossYield,
            netYield: netYield,
            monthlyGrossCashflow: operation.monthlyRent - monthlyTotalLoan,
            monthlyNetCashflow: netOperatingIncome / 12 - monthlyTotalLoan,
            monthlyNetNetCashflow: averageAnnualCashflowAfterTax / 12,
            monthlyNetNetCashflowFirstYear: (projections.first?.cashflowAfterTax ?? 0) / 12,
            monthlyAverageTax: averageAnnualTax / 12,
            projections: projections,
            warnings: warnings(for: input, costs: costs, annualGrossRent: annualGrossRent, isDenormandieEligible: isDenormandieEligible)
        )
    }

    // MARK: - Contrôles de cohérence

    private static func warnings(
        for input: SimulationInput,
        costs: CostBreakdown,
        annualGrossRent: Double,
        isDenormandieEligible: Bool
    ) -> [SimulationWarning] {
        var warnings: [SimulationWarning] = []
        let regime = input.taxation.regime

        switch regime {
        case .lmnpMicroBIC where annualGrossRent > FiscalConstants.microBICCeiling:
            warnings.append(.init(severity: .warning, message: "Recettes supérieures au plafond Micro-BIC (77 700 €) : le régime réel s'applique de plein droit."))
        case .microFoncier where annualGrossRent > FiscalConstants.microFoncierCeiling:
            warnings.append(.init(severity: .warning, message: "Loyers supérieurs au plafond Micro-Foncier (15 000 €) : le régime réel s'applique de plein droit."))
        case .foncierReel where costs.works > 0:
            warnings.append(.init(severity: .info, message: "Déficit foncier : le bien doit rester loué nu jusqu'au 31/12 de la 3e année suivant l'imputation. Seuls les travaux d'entretien, réparation et amélioration sont déductibles."))
        case .denormandie:
            if !input.taxation.isDenormandieZone {
                warnings.append(.init(severity: .warning, message: "Commune non éligible Denormandie (hors Action Cœur de Ville / ORT) : aucune réduction d'impôt, calcul en foncier réel."))
            } else if !isDenormandieEligible {
                warnings.append(.init(severity: .warning, message: "Travaux inférieurs à 25 % du coût total de l'opération : réduction Denormandie non applicable, calcul en foncier réel."))
            } else {
                warnings.append(.init(severity: .info, message: "Denormandie : loyers et ressources des locataires plafonnés. Réduction plafonnée à 10 000 €/an (niches fiscales) et limitée à l'impôt dû."))
            }
        case .sciIS:
            warnings.append(.init(severity: .info, message: "SCI IS : cash-flow calculé au niveau de la société, avant distribution (dividendes soumis au PFU). Plus-value de cession calculée sur la valeur nette comptable."))
        case .lmnpReel:
            warnings.append(.init(severity: .info, message: "LMNP réel : depuis la LF 2025, les amortissements déduits sont réintégrés dans le calcul de la plus-value à la revente."))
        default:
            break
        }

        if input.financing.downPayment > costs.total {
            warnings.append(.init(severity: .warning, message: "L'apport dépasse le coût total de l'opération : aucun emprunt nécessaire."))
        }
        if input.acquisition.surface > 0, input.operation.monthlyRent / input.acquisition.surface > 30 {
            warnings.append(.init(severity: .warning, message: "Loyer supérieur à 30 €/m² : vérifier l'estimation et l'encadrement des loyers."))
        }
        return warnings
    }
}
