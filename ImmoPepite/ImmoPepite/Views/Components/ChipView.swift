import SwiftUI

/// Tag sélectionnable (départements, villes, régimes fiscaux).
struct ChipView: View {
    let title: String
    var isSelected = false
    var showsRemoveIcon = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if showsRemoveIcon {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Badge mis en avant quand le cash-flow net-net est positif.
struct PepiteBadge: View {
    var body: some View {
        Label("PÉPITE", systemImage: "sparkles")
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.black)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.84, blue: 0.2), Color(red: 1, green: 0.62, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: .orange.opacity(0.5), radius: 6, y: 2)
            .accessibilityLabel("Pépite : cash-flow net-net positif")
    }
}

/// Indicateur clé (valeur + libellé).
struct MetricTile: View {
    let title: String
    let value: String
    var tint: Color = .primary
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

/// Curseur avec libellé et valeur formatée.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .font(.body.monospacedDigit().weight(.semibold))
            }
            Slider(value: $value, in: range, step: step)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Visuel d'annonce avec repli si l'image est indisponible.
struct PropertyImageView: View {
    let url: URL?
    let type: PropertyType

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure, .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.5), .teal.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: type.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
