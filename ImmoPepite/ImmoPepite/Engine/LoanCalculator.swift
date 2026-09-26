import Foundation

/// Agrégat annuel du tableau d'amortissement.
struct LoanYear: Hashable, Sendable {
    let interest: Double
    let principal: Double
    let insurance: Double
    let remainingPrincipal: Double

    static let zero = LoanYear(interest: 0, principal: 0, insurance: 0, remainingPrincipal: 0)
}

struct LoanSchedule: Hashable, Sendable {
    let principal: Double
    /// Mensualité capital + intérêts (hors assurance).
    let monthlyPayment: Double
    /// Assurance emprunteur mensuelle (assise sur le capital initial).
    let monthlyInsurance: Double
    let years: [LoanYear]

    var totalInterest: Double { years.reduce(0) { $0 + $1.interest } }
    var totalInsurance: Double { years.reduce(0) { $0 + $1.insurance } }

    /// Agrégat de l'année `year` (1-indexée) ; zéro une fois le prêt remboursé.
    func year(_ year: Int) -> LoanYear {
        guard year >= 1, year <= years.count else { return .zero }
        return years[year - 1]
    }
}

/// Prêt amortissable à mensualités constantes.
enum LoanCalculator {
    /// Mensualité constante : M = C × t / (1 − (1 + t)^−n), t = taux mensuel.
    static func monthlyPayment(principal: Double, annualRate: Double, durationYears: Int) -> Double {
        let months = durationYears * 12
        guard principal > 0, months > 0 else { return 0 }
        let monthlyRate = annualRate / 12
        guard monthlyRate > 0 else { return principal / Double(months) }
        return principal * monthlyRate / (1 - pow(1 + monthlyRate, -Double(months)))
    }

    static func schedule(
        principal: Double,
        annualRate: Double,
        durationYears: Int,
        annualInsuranceRate: Double
    ) -> LoanSchedule {
        let payment = monthlyPayment(principal: principal, annualRate: annualRate, durationYears: durationYears)
        let monthlyInsurance = principal > 0 ? principal * annualInsuranceRate / 12 : 0
        let monthlyRate = annualRate / 12

        var remaining = principal
        var years: [LoanYear] = []
        years.reserveCapacity(max(durationYears, 0))

        for _ in 0..<max(durationYears, 0) {
            var interest = 0.0
            var repaid = 0.0
            for _ in 0..<12 {
                let monthInterest = remaining * monthlyRate
                let monthPrincipal = min(payment - monthInterest, remaining)
                interest += monthInterest
                repaid += monthPrincipal
                remaining -= monthPrincipal
            }
            remaining = max(remaining, 0)
            years.append(LoanYear(
                interest: interest,
                principal: repaid,
                insurance: monthlyInsurance * 12,
                remainingPrincipal: remaining
            ))
        }

        return LoanSchedule(
            principal: principal,
            monthlyPayment: payment,
            monthlyInsurance: monthlyInsurance,
            years: years
        )
    }
}
