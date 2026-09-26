import SwiftUI

struct PropertyCardView: View {
    let item: PropertyListItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    private var property: Property { item.property }
    private var result: SimulationResult { item.result }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertyImageView(url: property.imageURL, type: property.type)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) {
                    if result.isPepite {
                        PepiteBadge().padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(isFavorite ? Color.red : Color.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(property.price.euros)
                        .font(.title2.bold())
                    Spacer()
                    Text("\(Int(property.surface)) m² · \(property.rooms) p.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(property.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Label(property.locationLabel, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 12) {
                    metric(
                        title: "Travaux",
                        value: property.estimatedWorks > 0 ? property.estimatedWorks.euros : "Aucun",
                        tint: .primary
                    )
                    metric(title: "Rdt brut", value: result.grossYield.percent, tint: .primary)
                    metric(
                        title: "CF net-net",
                        value: "\(result.monthlyNetNetCashflow.signedEuros)/m",
                        tint: result.monthlyNetNetCashflow.cashflowColor
                    )
                }
            }
            .padding(14)
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(result.isPepite ? Color.orange.opacity(0.7) : Color(.separator), lineWidth: result.isPepite ? 2 : 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
