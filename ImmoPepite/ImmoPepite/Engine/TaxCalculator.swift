import Foundation

/// Données d'exploitation invariantes d'une année sur l'autre, fournies au calcul fiscal.
struct TaxContext: Sendable {
    let regime: FiscalRegime
    let rentCollected: Double
    /// Charges d'exploitation annuelles (copropriété, TF, gestion, PNO, comptabilité).
    let operatingCharges: Double
    let purchasePrice: Double
    let agencyFees: Double
    let notaryFees: Double
    let works: Double
    let furniture: Double
    let landShare: Double
    let marginalTaxRate: Double
    let socialContributionsRate: Double
    let denormandieCommitment: DenormandieCommitment
    let isDenormandieEligible: Bool
}

/// Reports fiscaux transmis d'une année à l'autre.
struct TaxCarryState: Sendable {
    /// LMNP : déficit BIC reportable.
    var bicDeficit = 0.0
    /// LMNP : amortissements réputés différés (report illimité).
    var deferredDepreciation = 0.0
    /// Foncier : déficit imputable sur les revenus fonciers futurs.
    var landDeficit = 0.0
    /// SCI IS : déficits reportables.
    var corporateLoss = 0.0
}

struct TaxYearResult: Sendable {
    var taxableIncome = 0.0
    var incomeTax = 0.0
    var socialContributions = 0.0
    var corporateTax = 0.0
    var deficitTaxSaving = 0.0
    var taxReduction = 0.0
}

/// Calcul fiscal annuel par régime. Fonctions pures : tout l'état passe par `TaxCarryState`.
enum TaxCalculator {
    static func compute(year: Int, context ctx: TaxContext, loan: LoanYear, state: inout TaxCarryState) -> TaxYearResult {
        switch ctx.regime {
        case .lmnpMicroBIC:
            micro(revenue: ctx.rentCollected, allowance: FiscalConstants.microBICAllowance, context: ctx)
        case .microFoncier:
            micro(revenue: ctx.rentCollected, allowance: FiscalConstants.microFoncierAllowance, context: ctx)
        case .lmnpReel:
            lmnpReal(year: year, context: ctx, loan: loan, state: &state)
        case .foncierReel:
            realLandIncome(year: year, context: ctx, loan: loan, deductWorks: true, state: &state)
        case .denormandie:
            denormandie(year: year, context: ctx, loan: loan, state: &state)
        case .sciIS:
            corporate(year: year, context: ctx, loan: loan, state: &state)
        }
    }

    // MARK: - Micro-BIC / Micro-foncier

    private static func micro(revenue: Double, allowance: Double, context ctx: TaxContext) -> TaxYearResult {
        let taxable = max(revenue * (1 - allowance), 0)
        return personalIncomeTax(on: taxable, context: ctx)
    }

    // MARK: - LMNP réel

    private static func lmnpReal(year: Int, context ctx: TaxContext, loan: LoanYear, state: inout TaxCarryState) -> TaxYearResult {
        // Frais d'acquisition incorporés au prix de revient amortissable (hors quote-part terrain).
        let buildingBase = (ctx.purchasePrice + ctx.notaryFees + ctx.agencyFees) * (1 - ctx.landShare)
        let depreciation = straightLine(buildingBase, years: FiscalConstants.buildingDepreciationYears, year: year)
            + straightLine(ctx.works, years: FiscalConstants.worksDepreciationYears, year: year)
            + straightLine(ctx.furniture, years: FiscalConstants.furnitureDepreciationYears, year: year)

        let deductible = ctx.operatingCharges + loan.interest + loan.insurance
        let resultBeforeDepreciation = ctx.rentCollected - deductible

        guard resultBeforeDepreciation > 0 else {
            // Art. 39 C CGI : l'amortissement ne peut ni créer ni augmenter un déficit.
            state.bicDeficit += -resultBeforeDepreciation
            state.deferredDepreciation += depreciation
            return TaxYearResult()
        }

        let usedDeficit = min(resultBeforeDepreciation, state.bicDeficit)
        state.bicDeficit -= usedDeficit
        var result = resultBeforeDepreciation - usedDeficit

        let availableDepreciation = depreciation + state.deferredDepreciation
        let usedDepreciation = min(result, availableDepreciation)
        state.deferredDepreciation = availableDepreciation - usedDepreciation
        result -= usedDepreciation

        return personalIncomeTax(on: result, context: ctx)
    }

    // MARK: - Foncier réel & déficit foncier

    private static func realLandIncome(
        year: Int,
        context ctx: TaxContext,
        loan: LoanYear,
        deductWorks: Bool,
        state: inout TaxCarryState
    ) -> TaxYearResult {
        // L'assurance emprunteur suit le régime des intérêts (frais d'emprunt).
        let interestCharges = loan.interest + loan.insurance
        var otherCharges = ctx.operatingCharges + FiscalConstants.foncierFlatManagementAllowance
        if deductWorks && year == 1 {
            otherCharges += ctx.works
        }

        let revenue = ctx.rentCollected
        let result = revenue - interestCharges - otherCharges

        if result >= 0 {
            let usedDeficit = min(result, state.landDeficit)
            state.landDeficit -= usedDeficit
            return personalIncomeTax(on: result - usedDeficit, context: ctx)
        }

        // Seule la fraction du déficit issue des charges hors intérêts s'impute sur le revenu global.
        let interestDeficit = max(0, interestCharges - revenue)
        let revenueAfterInterest = max(0, revenue - interestCharges)
        let otherDeficit = max(0, otherCharges - revenueAfterInterest)
        let imputableOnGlobalIncome = min(otherDeficit, FiscalConstants.landDeficitGlobalCeiling)

        state.landDeficit += interestDeficit + (otherDeficit - imputableOnGlobalIncome)

        var output = TaxYearResult()
        output.deficitTaxSaving = imputableOnGlobalIncome * ctx.marginalTaxRate
        return output
    }

    // MARK: - Denormandie

    private static func denormandie(year: Int, context ctx: TaxContext, loan: LoanYear, state: inout TaxCarryState) -> TaxYearResult {
        // Si la réduction s'applique, les travaux sont inclus dans sa base et ne sont pas déductibles.
        var output = realLandIncome(
            year: year,
            context: ctx,
            loan: loan,
            deductWorks: !ctx.isDenormandieEligible,
            state: &state
        )
        output.taxReduction = denormandieReduction(year: year, context: ctx)
        return output
    }

    static func denormandieBase(context ctx: TaxContext) -> Double {
        min(ctx.purchasePrice + ctx.agencyFees + ctx.notaryFees + ctx.works, FiscalConstants.denormandieBaseCeiling)
    }

    static func denormandieReduction(year: Int, context ctx: TaxContext) -> Double {
        guard ctx.isDenormandieEligible else { return 0 }
        let reduction = denormandieBase(context: ctx) * ctx.denormandieCommitment.annualRate(forYear: year)
        return min(reduction, FiscalConstants.taxNicheCeiling)
    }

    // MARK: - SCI à l'IS

    private static func corporate(year: Int, context ctx: TaxContext, loan: LoanYear, state: inout TaxCarryState) -> TaxYearResult {
        var charges = ctx.operatingCharges + loan.interest + loan.insurance
        if year == 1 {
            // Option pour la déduction immédiate des frais d'acquisition.
            charges += ctx.notaryFees + ctx.agencyFees
        }
        let depreciation = straightLine(ctx.purchasePrice * (1 - ctx.landShare), years: FiscalConstants.buildingDepreciationYears, year: year)
            + straightLine(ctx.works, years: FiscalConstants.worksDepreciationYears, year: year)

        let result = ctx.rentCollected - charges - depreciation
        var output = TaxYearResult()

        guard result > 0 else {
            state.corporateLoss += -result
            return output
        }

        let usedLoss = min(result, state.corporateLoss)
        state.corporateLoss -= usedLoss
        let taxable = result - usedLoss

        output.taxableIncome = taxable
        output.corporateTax = corporateTax(on: taxable)
        return output
    }

    static func corporateTax(on taxable: Double) -> Double {
        guard taxable > 0 else { return 0 }
        let reducedBracket = min(taxable, FiscalConstants.corporateReducedRateThreshold)
        let standardBracket = max(taxable - FiscalConstants.corporateReducedRateThreshold, 0)
        return reducedBracket * FiscalConstants.corporateReducedRate + standardBracket * FiscalConstants.corporateStandardRate
    }

    // MARK: - Helpers

    private static func personalIncomeTax(on taxable: Double, context ctx: TaxContext) -> TaxYearResult {
        let base = max(taxable, 0)
        var output = TaxYearResult()
        output.taxableIncome = base
        output.incomeTax = base * ctx.marginalTaxRate
        output.socialContributions = base * ctx.socialContributionsRate
        return output
    }

    static func straightLine(_ base: Double, years: Int, year: Int) -> Double {
        guard base > 0, years > 0, year >= 1, year <= years else { return 0 }
        return base / Double(years)
    }
}
