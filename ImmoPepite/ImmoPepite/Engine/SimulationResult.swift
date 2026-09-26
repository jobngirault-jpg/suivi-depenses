import Foundation

struct SimulationWarning: Hashable, Sendable, Identifiable {
    enum Severity: Hashable, Sendable {
        case info
        case warning
    }

    let severity: Severity
    let message: String

    var id: String { message }
}

/// Projection d'une année d'exploitation (montants annuels, en €).
struct YearlyProjection: Hashable, Sendable, Identifiable {
    let year: Int
    let rentCollected: Double
    let operatingCharges: Double
    let loanInterest: Double
    let loanInsurance: Double
    let principalRepaid: Double
    let remainingPrincipal: Double
    let taxableIncome: Double
    let incomeTax: Double
    let socialContributions: Double
    let corporateTax: Double
    /// Économie d'impôt liée au déficit foncier imputé sur le revenu global.
    let deficitTaxSaving: Double
    /// Réduction d'impôt (Denormandie).
    let taxReduction: Double

    var id: Int { year }

    var loanPayments: Double { loanInterest + loanInsurance + principalRepaid }
    /// Impôt net de l'année (négatif = gain fiscal).
    var netTax: Double { incomeTax + socialContributions + corporateTax - deficitTaxSaving - taxReduction }
    var cashflowBeforeTax: Double { rentCollected - operatingCharges - loanPayments }
    var cashflowAfterTax: Double { cashflowBeforeTax - netTax }
}

struct CostBreakdown: Hashable, Sendable {
    let purchasePrice: Double
    let agencyFees: Double
    let notaryFees: Double
    let works: Double
    let furniture: Double

    var total: Double { purchasePrice + agencyFees + notaryFees + works + furniture }
}

struct SimulationResult: Hashable, Sendable {
    let costs: CostBreakdown
    let downPayment: Double
    let loanAmount: Double

    // MARK: Crédit
    /// Mensualité capital + intérêts.
    let monthlyLoanPayment: Double
    let monthlyLoanInsurance: Double
    let totalInterest: Double
    let totalInsurance: Double

    // MARK: Rendements
    /// Loyer annuel théorique / coût total de l'opération.
    let grossYield: Double
    /// (Loyers encaissés − charges d'exploitation) / coût total de l'opération.
    let netYield: Double

    // MARK: Cash-flows mensuels
    /// Loyer − mensualité totale.
    let monthlyGrossCashflow: Double
    /// Loyer encaissé − charges − mensualité totale.
    let monthlyNetCashflow: Double
    /// Cash-flow net de charges et d'impôts, lissé sur l'horizon de projection.
    let monthlyNetNetCashflow: Double
    /// Cash-flow net-net de la première année (inclut les effets fiscaux one-shot).
    let monthlyNetNetCashflowFirstYear: Double
    /// Impôt mensuel moyen (négatif = gain fiscal).
    let monthlyAverageTax: Double

    let projections: [YearlyProjection]
    let warnings: [SimulationWarning]

    var monthlyTotalLoanPayment: Double { monthlyLoanPayment + monthlyLoanInsurance }

    /// Effort d'épargne mensuel réel à fournir par l'investisseur.
    var monthlySavingsEffort: Double { max(0, -monthlyNetNetCashflow) }

    /// Une « pépite » s'autofinance entièrement, impôts compris.
    var isPepite: Bool { monthlyNetNetCashflow > 0 }
}
