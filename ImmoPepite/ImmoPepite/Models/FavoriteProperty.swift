import Foundation
import SwiftData

/// Annonce mise en favori. L'annonce complète est conservée en snapshot JSON :
/// elle reste consultable même si elle disparaît de la source.
@Model
final class FavoriteProperty {
    @Attribute(.unique) var propertyID: String
    var addedAt: Date
    var title: String
    var city: String
    var price: Double
    var payload: Data

    init(property: Property, addedAt: Date = .now) {
        self.propertyID = property.id
        self.addedAt = addedAt
        self.title = property.title
        self.city = property.locationLabel
        self.price = property.price
        self.payload = (try? JSONEncoder().encode(property)) ?? Data()
    }

    var property: Property? {
        try? JSONDecoder().decode(Property.self, from: payload)
    }
}
