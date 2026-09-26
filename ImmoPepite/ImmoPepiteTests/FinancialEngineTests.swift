import Foundation
import Testing
@testable import ImmoPepite

@Suite("Moteur financier")
struct FinancialEngineTests {
    // MARK: Fixture

    private func makeInput(
        price: Double = 100_000,
        works: Double = 0,
        rent: Double = 700,
        downPayment: Double = 0,
        regime: FiscalRegime = .lmnpMicroBIC,
        condition: PropertyCondition = .old,
        vacancy: Double = 0,
        isDenormandieZone: Bool = false
    ) -> SimulationInput {
        SimulationInput(
            acquisition: AcquisitionInput(
                purchasePrice: price,
                agencyFees: 0,
                surface: 50,
                worksMode: .fixedAmount,
                worksAmount: works,
                worksPerSquareMeter: 0,
                condition: condition,
                notaryFeesOverride: nil,
                furnitureAmount: 0
            ),
            financing: FinancingInput(downPayment: downPayment, annualRate: 0.03, durationYears: 20, insuranceRate: 0),
            operation: OperationInput(
                monthlyRent: rent,
                monthlyCondoFees: 0,
                annualPropertyTax: 0,
                managementFeeRate: 0,
                vacancyRate: vacancy,
                annualPNOInsurance: 0
            ),
            taxation: TaxationInput(regime: regime, marginalTaxRate: 0.30, isDenormandieZone: isDenormandieZone)
        )
    }

    // MARK: Crédit

    @Test("Mensualité d'un prêt de 100 000 € à 3 % sur 20 ans")
    func monthlyPayment() {
        let payment = LoanCalculator.monthlyPayment(principal: 100_000, annualRate: 0.03, durationYears: 20)
        #expect(abs(payment - 554.60) < 0.01)
    }

    @Test("Le tableau d'amortissement solde le capital")
    func scheduleRepaysPrincipal() {
        let schedule = LoanCalculator.schedule(principal: 150_000, annualRate: 0.034, durationYears: 25, annualInsuranceRate: 0.003)
        let repaid = schedule.years.reduce(0) { $0 + $1.principal }
        #expect(abs(repaid - 150_000) < 0.5)
        #expect(schedule.years.last?.remainingPrincipal ?? 1 < 0.5)
        #expect(abs(schedule.monthlyInsurance - 37.5) < 0.001)
    }

    @Test("Taux nul : remboursement linéaire")
    func zeroRateLoan() {
        #expect(LoanCalculator.monthlyPayment(principal: 24_000, annualRate: 0, durationYears: 2) == 1_000)
    }

    // MARK: Acquisition

    @Test("Frais de notaire automatiques ancien / neuf")
    func notaryFees() {
        #expect(makeInput(condition: .old).acquisition.notaryFees == 7_500)
        #expect(makeInput(condition: .new).acquisition.notaryFees == 2_500)
    }

    @Test("Travaux au m²")
    func worksPerSquareMeter() {
        var input = makeInput()
        input.acquisition.worksMode = .perSquareMeter
        input.acquisition.worksPerSquareMeter = 400
        #expect(input.acquisition.worksTotal == 20_000)
    }

    // MARK: Rendements & cash-flow

    @Test("Rendement brut calculé sur le coût total")
    func grossYield() {
        let result = FinancialEngine.simulate(makeInput(rent: 700))
        #expect(abs(result.grossYield - 8_400 / 107_500) < 1e-9)
    }

    @Test("Effort d'épargne = opposé du cash-flow net-net négatif")
    func savingsEffort() {
        let result = FinancialEngine.simulate(makeInput(rent: 300))
        #expect(result.monthlyNetNetCashflow < 0)
        #expect(abs(result.monthlySavingsEffort + result.monthlyNetNetCashflow) < 1e-9)
    }

    // MARK: Fiscalité

    @Test("Micro-BIC : abattement 50 %, IR + prélèvements sociaux")
    func microBIC() {
        let result = FinancialEngine.simulate(makeInput(rent: 600, downPayment: 107_500, regime: .lmnpMicroBIC))
        let expectedTax = 7_200 * 0.5 * (0.30 + 0.172)
        #expect(abs(result.projections[0].netTax - expectedTax) < 0.01)
    }

    @Test("Micro-foncier : abattement 30 %")
    func microFoncier() {
        let result = FinancialEngine.simulate(makeInput(rent: 600, downPayment: 107_500, regime: .microFoncier))
        let expectedTax = 7_200 * 0.7 * (0.30 + 0.172)
        #expect(abs(result.projections[0].netTax - expectedTax) < 0.01)
    }

    @Test("Foncier réel : déficit imputable plafonné à 10 700 €")
    func landDeficitCeiling() {
        let result = FinancialEngine.simulate(makeInput(works: 40_000, rent: 500, downPayment: 200_000, regime: .foncierReel))
        let year1 = result.projections[0]
        #expect(abs(year1.deficitTaxSaving - 10_700 * 0.30) < 0.01)
        // Le reliquat reporté absorbe les revenus fonciers de l'année 2.
        #expect(result.projections[1].netTax == 0)
    }

    @Test("LMNP réel : l'amortissement ne crée pas de déficit")
    func lmnpDepreciationDoesNotCreateDeficit() {
        // Loyers 3 600 € − comptabilité 500 € < amortissements (~5 046 €/an) : résultat nul, pas de déficit.
        let result = FinancialEngine.simulate(makeInput(works: 30_000, rent: 300, downPayment: 200_000, regime: .lmnpReel))
        #expect(result.projections.allSatisfy { $0.netTax == 0 })
        #expect(result.projections.allSatisfy { $0.taxableIncome == 0 })
    }

    @Test("Denormandie : travaux ≥ 25 % requis")
    func denormandieEligibility() {
        let eligible = FinancialEngine.simulate(makeInput(price: 90_000, works: 35_000, regime: .denormandie, isDenormandieZone: true))
        let base = 90_000 + 6_750 + 35_000.0
        #expect(abs(eligible.projections[0].taxReduction - base * 0.02) < 0.01)

        let ineligible = FinancialEngine.simulate(makeInput(price: 90_000, works: 10_000, regime: .denormandie, isDenormandieZone: true))
        #expect(ineligible.projections[0].taxReduction == 0)
        #expect(ineligible.warnings.contains { $0.severity == .warning })
    }

    @Test("Denormandie 12 ans : 2 %/an jusqu'à 9 ans puis 1 %")
    func denormandieSchedule() {
        #expect(DenormandieCommitment.twelveYears.annualRate(forYear: 9) == 0.02)
        #expect(DenormandieCommitment.twelveYears.annualRate(forYear: 10) == 0.01)
        #expect(DenormandieCommitment.sixYears.annualRate(forYear: 7) == 0)
    }

    @Test("Barème IS 15 % / 25 %")
    func corporateTax() {
        #expect(abs(TaxCalculator.corporateTax(on: 50_000) - 8_250) < 0.001)
        #expect(TaxCalculator.corporateTax(on: -1_000) == 0)
    }

    // MARK: Données de démonstration

    @Test("Le jeu de démo contient des pépites et des biens à effort d'épargne")
    func mockDataMix() {
        let results = MockData.properties.map { FinancialEngine.simulate(.make(for: $0, profile: .default)) }
        #expect(MockData.properties.count == 5)
        #expect(Set(MockData.properties.map(\.departmentCode)).count == 5)
        #expect(results.contains { $0.isPepite })
        #expect(results.contains { !$0.isPepite })
    }
}
