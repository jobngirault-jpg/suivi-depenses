import Foundation
import Observation

/// Brouillon de filtre édité dans `FilterView`, appliqué uniquement à la validation.
@Observable
@MainActor
final class FilterViewModel {
    var draft: SearchFilter
    var citySearchText = ""

    let departments: [Department]

    init(filter: SearchFilter, departments: [Department] = DepartmentCatalog.all) {
        self.draft = filter
        self.departments = departments
    }

    // MARK: Départements

    func isSelected(_ department: Department) -> Bool {
        draft.departmentCodes.contains(department.code)
    }

    func toggle(_ department: Department) {
        draft.toggleDepartment(department.code)
    }

    var selectedDepartments: [Department] {
        departments.filter { isSelected($0) }
    }

    // MARK: Villes / codes postaux

    func isSelected(_ city: City) -> Bool {
        draft.postalCodes.contains(city.postalCode)
    }

    func toggle(_ city: City) {
        draft.togglePostalCode(city.postalCode)
    }

    /// Villes des départements sélectionnés, filtrées par la recherche (nom ou code postal).
    func availableCities(in department: Department) -> [City] {
        let query = citySearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return department.cities }
        return department.cities.filter {
            $0.name.localizedStandardContains(query) || $0.postalCode.hasPrefix(query)
        }
    }

    /// Tags actifs : un par code postal sélectionné.
    var selectedCityTags: [City] {
        draft.postalCodes.sorted().map { postalCode in
            DepartmentCatalog.city(postalCode: postalCode) ?? City(name: postalCode, postalCode: postalCode)
        }
    }

    // MARK: Critères financiers

    var isMinYieldEnabled: Bool {
        get { draft.minGrossYield != nil }
        set { draft.minGrossYield = newValue ? (draft.minGrossYield ?? 0.08) : nil }
    }

    var minYield: Double {
        get { draft.minGrossYield ?? 0.08 }
        set { draft.minGrossYield = newValue }
    }

    var isMinCashflowEnabled: Bool {
        get { draft.minMonthlyCashflow != nil }
        set { draft.minMonthlyCashflow = newValue ? (draft.minMonthlyCashflow ?? 0) : nil }
    }

    var minCashflow: Double {
        get { draft.minMonthlyCashflow ?? 0 }
        set { draft.minMonthlyCashflow = newValue }
    }

    var isMaxPriceEnabled: Bool {
        get { draft.maxPrice != nil }
        set { draft.maxPrice = newValue ? (draft.maxPrice ?? 150_000) : nil }
    }

    var maxPrice: Double {
        get { draft.maxPrice ?? 150_000 }
        set { draft.maxPrice = newValue }
    }

    func reset() {
        draft = .empty
        citySearchText = ""
    }
}
