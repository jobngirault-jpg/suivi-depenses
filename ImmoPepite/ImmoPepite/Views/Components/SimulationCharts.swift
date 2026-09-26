import Charts
import SwiftUI

// MARK: - Répartition des coûts

struct CostBreakdownChart: View {
    let costs: CostBreakdown

    private struct Slice: Identifiable {
        let label: String
        let amount: Double
        let color: Color
        var id: String { label }
    }

    private var slices: [Slice] {
        [
            Slice(label: "Achat", amount: costs.purchasePrice, color: .indigo),
            Slice(label: "Travaux", amount: costs.works, color: .orange),
            Slice(label: "Notaire", amount: costs.notaryFees, color: .teal),
            Slice(label: "Agence", amount: costs.agencyFees, color: .pink),
            Slice(label: "Mobilier", amount: costs.furniture, color: .purple),
        ].filter { $0.amount > 0 }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Montant", slice.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(slice.color)
            }
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(costs.total.euros)
                        .font(.caption.bold().monospacedDigit())
                        .minimumScaleFactor(0.6)
                }
                .padding(28)
            }
            .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    HStack(spacing: 8) {
                        Circle().fill(slice.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(slice.label).font(.caption)
                            Text("\(slice.amount.euros) · \((slice.amount / max(costs.total, 1)).percent)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cascade du cash-flow mensuel

struct CashflowWaterfallView: View {
    let result: SimulationResult

    private var firstYear: YearlyProjection? { result.projections.first }

    var body: some View {
        VStack(spacing: 8) {
            if let year = firstYear {
                row("Loyers encaissés (vacance déduite)", year.rentCollected / 12)
                row("Charges d'exploitation", -year.operatingCharges / 12)
                row("Mensualité crédit + assurance", -result.monthlyTotalLoanPayment)
                Divider()
                row("Cash-flow net de charges", result.monthlyNetCashflow, emphasized: true)
                row("Fiscalité (moyenne lissée)", -result.monthlyAverageTax)
                Divider()
                row("Cash-flow NET-NET", result.monthlyNetNetCashflow, emphasized: true, colored: true)
            }
        }
    }

    private func row(_ title: String, _ value: Double, emphasized: Bool = false, colored: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text(value.signedEuros)
                .font(.subheadline.monospacedDigit().weight(emphasized ? .bold : .regular))
                .foregroundStyle(colored ? value.cashflowColor : (value < 0 ? Color.secondary : Color.primary))
        }
    }
}

// MARK: - Projection annuelle

struct CashflowProjectionChart: View {
    let projections: [YearlyProjection]

    var body: some View {
        Chart {
            ForEach(projections) { year in
                BarMark(
                    x: .value("Année", year.year),
                    y: .value("Cash-flow net-net", year.cashflowAfterTax / 12)
                )
                .foregroundStyle(year.cashflowAfterTax >= 0 ? Color.green.gradient : Color.red.gradient)
                .cornerRadius(3)
            }

            RuleMark(y: .value("Équilibre", 0))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartXAxis {
            AxisMarks(values: projections.map(\.year)) { value in
                AxisValueLabel {
                    if let year = value.as(Int.self) { Text("A\(year)") }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount.euros) }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Cash-flow net-net mensuel par année de détention")
    }
}
