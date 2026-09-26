import Foundation

/// Jeu de données de démonstration : 5 biens dans 5 départements différents.
/// Avec le profil par défaut (apport 10 %, 3,4 % sur 25 ans, TMI 30 %, LMNP réel) :
/// Saint-Étienne, Mâcon et Montluçon ressortent « PÉPITE » ; Vienne ne l'est qu'en Denormandie ;
/// Lyon 7e illustre un bien patrimonial à effort d'épargne élevé.
enum MockData {
    static let properties: [Property] = [
        Property(
            id: "mock-42-001",
            title: "T3 lumineux à rénover – quartier Jacquard",
            type: .apartment,
            price: 52_000,
            agencyFees: 0,
            surface: 62,
            rooms: 3,
            city: "Saint-Étienne",
            postalCode: "42000",
            departmentCode: "42",
            imageURL: URL(string: "https://picsum.photos/seed/immopepite-42/800/500"),
            listingURL: nil,
            summary: "3e étage avec ascenseur, double séjour, 2 chambres. Rafraîchissement complet (sols, peintures, cuisine, salle d'eau). Forte demande locative étudiante et jeunes actifs, proche tram T1.",
            estimatedWorks: 22_000,
            estimatedMonthlyRent: 690,
            monthlyCondoFees: 65,
            annualPropertyTax: 680,
            condition: .old,
            energyClass: "E",
            isDenormandieZone: false,
            source: "Démo",
            publishedAt: .now.addingTimeInterval(-2 * 86_400)
        ),
        Property(
            id: "mock-71-002",
            title: "Immeuble de rapport 4 lots – centre-ville",
            type: .building,
            price: 179_000,
            agencyFees: 0,
            surface: 210,
            rooms: 9,
            city: "Mâcon",
            postalCode: "71000",
            departmentCode: "71",
            imageURL: URL(string: "https://picsum.photos/seed/immopepite-71/800/500"),
            listingURL: nil,
            summary: "Monopropriété : 2 T2 + 1 T3 + 1 studio, compteurs individualisés. Deux lots à rénover (électricité, isolation, huisseries). Commune Action Cœur de Ville, gare TGV à 5 min.",
            estimatedWorks: 65_000,
            estimatedMonthlyRent: 2_150,
            monthlyCondoFees: 0,
            annualPropertyTax: 2_100,
            condition: .old,
            energyClass: "F",
            isDenormandieZone: true,
            source: "Démo",
            publishedAt: .now.addingTimeInterval(-86_400)
        ),
        Property(
            id: "mock-69-003",
            title: "T2 refait à neuf – Jean Macé",
            type: .apartment,
            price: 239_000,
            agencyFees: 0,
            surface: 45,
            rooms: 2,
            city: "Lyon 7e",
            postalCode: "69007",
            departmentCode: "69",
            imageURL: URL(string: "https://picsum.photos/seed/immopepite-69/800/500"),
            listingURL: nil,
            summary: "Immeuble ancien de standing, balcon sur cour. Petits travaux d'aménagement uniquement. Secteur soumis à l'encadrement des loyers : actif patrimonial plutôt que cash-flow.",
            estimatedWorks: 6_000,
            estimatedMonthlyRent: 920,
            monthlyCondoFees: 110,
            annualPropertyTax: 1_050,
            condition: .old,
            energyClass: "C",
            isDenormandieZone: false,
            source: "Démo",
            publishedAt: .now.addingTimeInterval(-5 * 86_400)
        ),
        Property(
            id: "mock-38-004",
            title: "T3 traversant à réhabiliter – cœur historique",
            type: .apartment,
            price: 89_000,
            agencyFees: 4_500,
            surface: 64,
            rooms: 3,
            city: "Vienne",
            postalCode: "38200",
            departmentCode: "38",
            imageURL: URL(string: "https://picsum.photos/seed/immopepite-38/800/500"),
            listingURL: nil,
            summary: "Passoire thermique (DPE G) : rénovation énergétique globale à prévoir. Travaux > 25 % du coût total : éligible Denormandie. 30 min de Lyon Part-Dieu en TER.",
            estimatedWorks: 36_000,
            estimatedMonthlyRent: 740,
            monthlyCondoFees: 70,
            annualPropertyTax: 720,
            condition: .old,
            energyClass: "G",
            isDenormandieZone: true,
            source: "Démo",
            publishedAt: .now.addingTimeInterval(-3 * 86_400)
        ),
        Property(
            id: "mock-03-005",
            title: "Maison de ville divisible en 2 logements",
            type: .house,
            price: 72_000,
            agencyFees: 0,
            surface: 110,
            rooms: 5,
            city: "Montluçon",
            postalCode: "03100",
            departmentCode: "03",
            imageURL: URL(string: "https://picsum.photos/seed/immopepite-03/800/500"),
            listingURL: nil,
            summary: "Maison R+2 avec entrées séparables : création d'un T2 et d'un T3. Toiture saine, travaux de second œuvre et mise aux normes. Zone Action Cœur de Ville.",
            estimatedWorks: 38_000,
            estimatedMonthlyRent: 860,
            monthlyCondoFees: 0,
            annualPropertyTax: 1_150,
            condition: .old,
            energyClass: "F",
            isDenormandieZone: true,
            source: "Démo",
            publishedAt: .now.addingTimeInterval(-7 * 86_400)
        ),
    ]
}

/// Service de démonstration utilisé tant qu'aucune URL d'API n'est configurée.
struct MockPropertyService: PropertyProviding {
    var latency: Duration = .milliseconds(450)

    func fetchProperties(filter: SearchFilter) async throws -> [Property] {
        try await Task.sleep(for: latency)
        return MockData.properties.filter { property in
            filter.matchesLocation(property) && (filter.maxPrice.map { property.price <= $0 } ?? true)
        }
    }

    func fetchProperty(id: String) async throws -> Property {
        try await Task.sleep(for: latency)
        guard let property = MockData.properties.first(where: { $0.id == id }) else {
            throw PropertyAPIError.notFound
        }
        return property
    }
}

enum PropertyServiceFactory {
    static func makeDefault() -> any PropertyProviding {
        if let configuration = APIConfiguration.fromEnvironment {
            return PropertyAPIService(configuration: configuration)
        }
        return MockPropertyService()
    }
}
