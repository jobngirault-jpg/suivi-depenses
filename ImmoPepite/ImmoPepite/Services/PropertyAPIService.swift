import Foundation

// MARK: - Contrat

/// Source d'annonces. Implémentée par le backend de scraping (`PropertyAPIService`)
/// et par un service de démonstration (`MockPropertyService`).
protocol PropertyProviding: Sendable {
    func fetchProperties(filter: SearchFilter) async throws -> [Property]
    func fetchProperty(id: String) async throws -> Property
}

enum PropertyAPIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case notFound
    case http(statusCode: Int)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL de l'API invalide."
        case .unauthorized: "Clé d'API invalide ou expirée."
        case .notFound: "Annonce introuvable."
        case .http(let statusCode): "Erreur serveur (HTTP \(statusCode))."
        case .decoding(let detail): "Réponse de l'API illisible : \(detail)"
        case .transport(let detail): "Connexion impossible : \(detail)"
        }
    }
}

// MARK: - Configuration

struct APIConfiguration: Sendable {
    let baseURL: URL
    let apiKey: String?
    var pageSize = 50

    /// Lue depuis les variables d'environnement du schéma Xcode
    /// (`IMMOPEPITE_API_BASE_URL`, `IMMOPEPITE_API_KEY`). `nil` → mode démo.
    static var fromEnvironment: APIConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        guard let rawURL = environment["IMMOPEPITE_API_BASE_URL"], let url = URL(string: rawURL) else {
            return nil
        }
        return APIConfiguration(baseURL: url, apiKey: environment["IMMOPEPITE_API_KEY"])
    }
}

// MARK: - Service HTTP

/// Client du backend agrégeant les annonces scrapées (LeBonCoin, SeLoger, PAP…).
///
/// Endpoints attendus :
/// - `GET /v1/listings?departments=69,38&postal_codes=69007&max_price=150000&limit=50`
///   → `{ "items": [ListingDTO], "next_cursor": "…" }`
/// - `GET /v1/listings/{id}` → `ListingDTO`
struct PropertyAPIService: PropertyProviding {
    let configuration: APIConfiguration
    let session: URLSession

    init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func fetchProperties(filter: SearchFilter) async throws -> [Property] {
        var queryItems = [URLQueryItem(name: "limit", value: String(configuration.pageSize))]
        if !filter.departmentCodes.isEmpty {
            queryItems.append(URLQueryItem(name: "departments", value: filter.departmentCodes.sorted().joined(separator: ",")))
        }
        if !filter.postalCodes.isEmpty {
            queryItems.append(URLQueryItem(name: "postal_codes", value: filter.postalCodes.sorted().joined(separator: ",")))
        }
        if let maxPrice = filter.maxPrice {
            queryItems.append(URLQueryItem(name: "max_price", value: String(Int(maxPrice))))
        }

        let response: ListingsResponseDTO = try await get(path: "v1/listings", queryItems: queryItems)
        return response.items.map { $0.toDomain() }
    }

    func fetchProperty(id: String) async throws -> Property {
        let dto: ListingDTO = try await get(path: "v1/listings/\(id)", queryItems: [])
        return dto.toDomain()
    }

    // MARK: Réseau

    private func get<Response: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> Response {
        guard var components = URLComponents(url: configuration.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw PropertyAPIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw PropertyAPIError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let exchange: (Data, URLResponse)
        do {
            exchange = try await session.data(for: request)
        } catch {
            throw PropertyAPIError.transport(error.localizedDescription)
        }
        let (data, response) = exchange

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 401, 403: throw PropertyAPIError.unauthorized
            case 404: throw PropertyAPIError.notFound
            default: throw PropertyAPIError.http(statusCode: http.statusCode)
            }
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw PropertyAPIError.decoding(String(describing: error))
        }
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - DTO

struct ListingsResponseDTO: Decodable, Sendable {
    let items: [ListingDTO]
    let nextCursor: String?
}

/// Format brut renvoyé par le backend de scraping. Les estimations (loyer, travaux)
/// sont optionnelles : à défaut, elles sont complétées par `MarketEstimator`.
struct ListingDTO: Decodable, Sendable {
    let id: String
    let source: String
    let title: String
    let propertyType: String?
    let price: Double
    let agencyFees: Double?
    let surface: Double
    let rooms: Int?
    let city: String
    let postalCode: String
    let imageUrls: [String]?
    let url: String?
    let description: String?
    let estimatedRent: Double?
    let estimatedWorks: Double?
    let condoFeesMonthly: Double?
    let propertyTaxYearly: Double?
    let isNew: Bool?
    let dpe: String?
    let denormandieZone: Bool?
    let publishedAt: Date?

    func toDomain() -> Property {
        let departmentCode = Department.code(forPostalCode: postalCode)
        return Property(
            id: id,
            title: title,
            type: propertyType.flatMap { PropertyType(rawValue: $0) } ?? .apartment,
            price: price,
            agencyFees: agencyFees ?? 0,
            surface: surface,
            rooms: rooms ?? 1,
            city: city,
            postalCode: postalCode,
            departmentCode: departmentCode,
            imageURL: imageUrls?.first.flatMap { URL(string: $0) },
            listingURL: url.flatMap { URL(string: $0) },
            summary: description ?? "",
            estimatedWorks: estimatedWorks ?? MarketEstimator.works(surface: surface, energyClass: dpe),
            estimatedMonthlyRent: estimatedRent ?? MarketEstimator.monthlyRent(surface: surface, departmentCode: departmentCode),
            monthlyCondoFees: condoFeesMonthly ?? 0,
            annualPropertyTax: propertyTaxYearly ?? MarketEstimator.propertyTax(surface: surface),
            condition: (isNew ?? false) ? .new : .old,
            energyClass: dpe,
            isDenormandieZone: denormandieZone ?? false,
            source: source,
            publishedAt: publishedAt ?? .now
        )
    }
}

// MARK: - Estimations de marché par défaut

/// Heuristiques de repli quand l'annonce ne fournit pas d'estimation.
enum MarketEstimator {
    /// Loyer hors charges moyen (€/m²) par département.
    private static let rentPerSquareMeter: [String: Double] = [
        "01": 11.5, "03": 8.0, "38": 12.5, "42": 9.0, "58": 7.5, "69": 15.0, "71": 8.5,
    ]

    static func monthlyRent(surface: Double, departmentCode: String) -> Double {
        (surface * (rentPerSquareMeter[departmentCode] ?? 10)).rounded()
    }

    /// Budget travaux selon l'étiquette DPE (rénovation énergétique).
    static func works(surface: Double, energyClass: String?) -> Double {
        let perSquareMeter: Double = switch (energyClass ?? "").uppercased() {
        case "G": 600
        case "F": 450
        case "E": 250
        case "D": 100
        default: 0
        }
        return (surface * perSquareMeter).rounded()
    }

    static func propertyTax(surface: Double) -> Double {
        (surface * 14).rounded()
    }
}
