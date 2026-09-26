import Foundation

struct SearchFilter: Codable, Hashable, Sendable {
    var departmentCodes: Set<String> = []
    /// Codes postaux sélectionnés. Un département sans code postal sélectionné est pris en entier.
    var postalCodes: Set<String> = []
    /// Rendement brut minimum (fraction).
    var minGrossYield: Double?
    /// Cash-flow net-net mensuel minimum (€).
    var minMonthlyCashflow: Double?
    var maxPrice: Double?
    var onlyPepites = false

    static let empty = SearchFilter()

    var activeCriteriaCount: Int {
        var count = departmentCodes.count + postalCodes.count
        if minGrossYield != nil { count += 1 }
        if minMonthlyCashflow != nil { count += 1 }
        if maxPrice != nil { count += 1 }
        if onlyPepites { count += 1 }
        return count
    }

    // MARK: Sélection

    mutating func toggleDepartment(_ code: String) {
        if departmentCodes.remove(code) != nil {
            postalCodes = postalCodes.filter { Department.code(forPostalCode: $0) != code }
        } else {
            departmentCodes.insert(code)
        }
    }

    mutating func togglePostalCode(_ postalCode: String) {
        if postalCodes.remove(postalCode) == nil {
            postalCodes.insert(postalCode)
            departmentCodes.insert(Department.code(forPostalCode: postalCode))
        }
    }

    // MARK: Correspondance

    func matchesLocation(_ property: Property) -> Bool {
        if !departmentCodes.isEmpty, !departmentCodes.contains(property.departmentCode) {
            return false
        }
        let selectedInDepartment = postalCodes.filter { Department.code(forPostalCode: $0) == property.departmentCode }
        return selectedInDepartment.isEmpty || selectedInDepartment.contains(property.postalCode)
    }

    func matches(_ property: Property, result: SimulationResult) -> Bool {
        guard matchesLocation(property) else { return false }
        if let maxPrice, property.price > maxPrice { return false }
        if let minGrossYield, result.grossYield < minGrossYield { return false }
        if let minMonthlyCashflow, result.monthlyNetNetCashflow < minMonthlyCashflow { return false }
        if onlyPepites, !result.isPepite { return false }
        return true
    }
}
