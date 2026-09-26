import Foundation

struct City: Identifiable, Hashable, Sendable {
    let name: String
    let postalCode: String

    var id: String { "\(postalCode)-\(name)" }
    var label: String { "\(name) · \(postalCode)" }
    var departmentCode: String { Department.code(forPostalCode: postalCode) }
}

struct Department: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let cities: [City]

    var id: String { code }
    /// Format d'affichage : « 69 - Rhône ».
    var label: String { "\(code) - \(name)" }

    /// Code département déduit d'un code postal (gère les DOM « 97x »).
    static func code(forPostalCode postalCode: String) -> String {
        postalCode.hasPrefix("97") ? String(postalCode.prefix(3)) : String(postalCode.prefix(2))
    }
}
