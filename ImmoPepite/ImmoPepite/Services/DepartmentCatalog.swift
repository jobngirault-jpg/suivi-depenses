import Foundation

/// Référentiel local des départements et communes proposés au filtrage.
/// À terme, alimenté par l'API (`GET /v1/departments`) ou la base officielle des codes postaux.
enum DepartmentCatalog {
    static let all: [Department] = [
        Department(code: "01", name: "Ain", cities: [
            City(name: "Bourg-en-Bresse", postalCode: "01000"),
            City(name: "Oyonnax", postalCode: "01100"),
            City(name: "Ambérieu-en-Bugey", postalCode: "01500"),
            City(name: "Trévoux", postalCode: "01600"),
        ]),
        Department(code: "03", name: "Allier", cities: [
            City(name: "Moulins", postalCode: "03000"),
            City(name: "Montluçon", postalCode: "03100"),
            City(name: "Vichy", postalCode: "03200"),
        ]),
        Department(code: "38", name: "Isère", cities: [
            City(name: "Grenoble", postalCode: "38000"),
            City(name: "Échirolles", postalCode: "38130"),
            City(name: "Vienne", postalCode: "38200"),
            City(name: "Bourgoin-Jallieu", postalCode: "38300"),
            City(name: "Voiron", postalCode: "38500"),
        ]),
        Department(code: "42", name: "Loire", cities: [
            City(name: "Saint-Étienne", postalCode: "42000"),
            City(name: "Saint-Étienne", postalCode: "42100"),
            City(name: "Roanne", postalCode: "42300"),
            City(name: "Montbrison", postalCode: "42600"),
            City(name: "Firminy", postalCode: "42700"),
        ]),
        Department(code: "58", name: "Nièvre", cities: [
            City(name: "Nevers", postalCode: "58000"),
            City(name: "Cosne-Cours-sur-Loire", postalCode: "58200"),
        ]),
        Department(code: "69", name: "Rhône", cities: [
            City(name: "Lyon 1er", postalCode: "69001"),
            City(name: "Lyon 2e", postalCode: "69002"),
            City(name: "Lyon 3e", postalCode: "69003"),
            City(name: "Lyon 4e", postalCode: "69004"),
            City(name: "Lyon 5e", postalCode: "69005"),
            City(name: "Lyon 6e", postalCode: "69006"),
            City(name: "Lyon 7e", postalCode: "69007"),
            City(name: "Lyon 8e", postalCode: "69008"),
            City(name: "Lyon 9e", postalCode: "69009"),
            City(name: "Villeurbanne", postalCode: "69100"),
            City(name: "Vénissieux", postalCode: "69200"),
            City(name: "Villefranche-sur-Saône", postalCode: "69400"),
            City(name: "Quincieux", postalCode: "69650"),
            City(name: "Givors", postalCode: "69700"),
            City(name: "Tarare", postalCode: "69170"),
        ]),
        Department(code: "71", name: "Saône-et-Loire", cities: [
            City(name: "Mâcon", postalCode: "71000"),
            City(name: "Chalon-sur-Saône", postalCode: "71100"),
            City(name: "Le Creusot", postalCode: "71200"),
            City(name: "Montceau-les-Mines", postalCode: "71300"),
        ]),
    ]

    static func department(code: String) -> Department? {
        all.first { $0.code == code }
    }

    static func city(postalCode: String) -> City? {
        all.lazy.flatMap(\.cities).first { $0.postalCode == postalCode }
    }
}
