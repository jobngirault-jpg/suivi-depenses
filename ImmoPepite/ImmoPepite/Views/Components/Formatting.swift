import Foundation
import SwiftUI

private let frenchLocale = Locale(identifier: "fr_FR")

extension Double {
    /// « 52 000 € »
    var euros: String {
        formatted(.currency(code: "EUR").precision(.fractionLength(0)).locale(frenchLocale))
    }

    /// « +91 € » / « −142 € »
    var signedEuros: String {
        formatted(.currency(code: "EUR").precision(.fractionLength(0)).sign(strategy: .always()).locale(frenchLocale))
    }

    /// « 9,9 % »
    var percent: String {
        formatted(.percent.precision(.fractionLength(1)).locale(frenchLocale))
    }

    /// « 3,40 % »
    var preciseRate: String {
        formatted(.percent.precision(.fractionLength(2)).locale(frenchLocale))
    }

    /// Couleur sémantique d'un cash-flow.
    var cashflowColor: Color {
        if self > 0 { return .green }
        if self > -100 { return .orange }
        return .red
    }
}
