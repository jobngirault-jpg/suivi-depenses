import SwiftData
import SwiftUI

struct PropertyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(InvestorProfileStore.self) private var profileStore
    @Query private var favoriteMatches: [FavoriteProperty]

    @State private var viewModel: PropertyDetailViewModel
    @State private var isSavePromptPresented = false
    @State private var simulationName = ""
    @State private var confirmationMessage: String?

    init(property: Property, profile: InvestorProfile, input: SimulationInput? = nil, savedSimulationID: UUID? = nil) {
        _viewModel = State(initialValue: PropertyDetailViewModel(
            property: property,
            profile: profile,
            input: input,
            savedSimulationID: savedSimulationID
        ))
        let propertyID = property.id
        _favoriteMatches = Query(filter: #Predicate<FavoriteProperty> { $0.propertyID == propertyID })
    }

    private var property: Property { viewModel.property }
    private var result: SimulationResult { viewModel.result }
    private var isFavorite: Bool { !favoriteMatches.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                keyMetrics
                regimeSection
                adjustmentsSection
                costSection
                cashflowSection
                projectionSection
                warningsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(property.city)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Enregistrer la simulation", isPresented: $isSavePromptPresented) {
            TextField("Nom de la simulation", text: $simulationName)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") { saveSimulation() }
        } message: {
            Text("Retrouvez-la dans l'onglet Favoris.")
        }
        .overlay(alignment: .bottom) { confirmationToast }
        .sensoryFeedback(.success, trigger: confirmationMessage)
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PropertyImageView(url: property.imageURL, type: property.type)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if result.isPepite {
                        PepiteBadge().padding(12)
                    }
                }

            Text(property.title)
                .font(.title3.bold())
            HStack {
                Label(property.locationLabel, systemImage: "mappin.and.ellipse")
                Spacer()
                if let energyClass = property.energyClass {
                    Text("DPE \(energyClass)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("\(property.price.euros) · \(Int(property.surface)) m² · \(property.pricePerSquareMeter.euros)/m²")
                .font(.subheadline.weight(.medium))

            if !property.summary.isEmpty {
                Text(property.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Indicateurs clés

    private var keyMetrics: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("Cash-flow NET-NET")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(result.monthlyNetNetCashflow.signedEuros) / mois")
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(result.monthlyNetNetCashflow.cashflowColor)
                    .contentTransition(.numericText(value: result.monthlyNetNetCashflow))
                    .animation(.snappy, value: result.monthlyNetNetCashflow)
                Text("Moyenne lissée sur \(result.projections.count) ans · Année 1 : \(result.monthlyNetNetCashflowFirstYear.signedEuros)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(title: "Mensualité totale", value: result.monthlyTotalLoanPayment.euros, systemImage: "building.columns")
                MetricTile(title: "Effort d'épargne", value: "\(result.monthlySavingsEffort.euros)/mois",
                           tint: result.monthlySavingsEffort > 0 ? .red : .green, systemImage: "banknote")
                MetricTile(title: "Rendement brut", value: result.grossYield.percent, systemImage: "percent")
                MetricTile(title: "Rendement net", value: result.netYield.percent, systemImage: "chart.line.uptrend.xyaxis")
                MetricTile(title: "Cash-flow brut", value: result.monthlyGrossCashflow.signedEuros,
                           tint: result.monthlyGrossCashflow.cashflowColor)
                MetricTile(title: "Cash-flow net", value: result.monthlyNetCashflow.signedEuros,
                           tint: result.monthlyNetCashflow.cashflowColor)
            }
        }
    }

    // MARK: Régime fiscal

    private var regimeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.regimeComparison()) { entry in
                            regimeChip(entry.regime, cashflow: entry.monthlyNetNetCashflow)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text(viewModel.input.taxation.regime.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Tranche marginale d'imposition", selection: $viewModel.input.taxation.marginalTaxRate) {
                    ForEach(FiscalConstants.marginalTaxRates, id: \.self) { rate in
                        Text("TMI \(rate.formatted(.percent))").tag(rate)
                    }
                }

                if viewModel.input.taxation.regime == .denormandie {
                    Picker("Engagement de location", selection: $viewModel.input.taxation.denormandieCommitment) {
                        ForEach(DenormandieCommitment.allCases) { commitment in
                            Text("\(commitment.label) (\(commitment.totalRate.formatted(.percent)))").tag(commitment)
                        }
                    }
                    Toggle("Commune éligible (Cœur de Ville / ORT)", isOn: $viewModel.input.taxation.isDenormandieZone)
                }
            }
        } label: {
            Label("Régime fiscal", systemImage: "doc.text.magnifyingglass")
        }
    }

    private func regimeChip(_ regime: FiscalRegime, cashflow: Double) -> some View {
        let isSelected = viewModel.input.taxation.regime == regime
        return Button {
            withAnimation(.snappy) { viewModel.input.taxation.regime = regime }
        } label: {
            VStack(spacing: 2) {
                Text(regime.shortLabel)
                    .font(.caption.weight(.semibold))
                Text(cashflow.signedEuros)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : cashflow.cashflowColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Curseurs

    private var adjustmentsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                LabeledSlider(
                    title: "Prix négocié",
                    value: $viewModel.input.acquisition.purchasePrice,
                    range: viewModel.priceRange,
                    step: 500,
                    format: \.euros,
                    caption: negotiationCaption
                )

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Saisie des travaux", selection: $viewModel.input.acquisition.worksMode) {
                        ForEach(WorksMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.input.acquisition.worksMode {
                    case .fixedAmount:
                        LabeledSlider(
                            title: "Travaux",
                            value: $viewModel.input.acquisition.worksAmount,
                            range: viewModel.worksRange,
                            step: 500,
                            format: \.euros
                        )
                    case .perSquareMeter:
                        LabeledSlider(
                            title: "Travaux au m²",
                            value: $viewModel.input.acquisition.worksPerSquareMeter,
                            range: viewModel.worksPerSquareMeterRange,
                            step: 10,
                            format: { "\($0.euros)/m²" },
                            caption: "Soit \(viewModel.input.acquisition.worksTotal.euros) pour \(Int(property.surface)) m²"
                        )
                    }
                }

                LabeledSlider(
                    title: "Loyer mensuel HC",
                    value: $viewModel.input.operation.monthlyRent,
                    range: viewModel.rentRange,
                    step: 10,
                    format: \.euros,
                    caption: property.surface > 0
                        ? "\((viewModel.input.operation.monthlyRent / property.surface).formatted(.number.precision(.fractionLength(1)))) €/m²"
                        : nil
                )

                LabeledSlider(
                    title: "Durée du prêt",
                    value: loanDurationBinding,
                    range: 10...30,
                    step: 1,
                    format: { "\(Int($0)) ans" },
                    caption: "Mensualité : \(result.monthlyLoanPayment.euros) + assurance \(result.monthlyLoanInsurance.euros)"
                )

                LabeledSlider(
                    title: "Taux d'emprunt",
                    value: $viewModel.input.financing.annualRate,
                    range: 0.01...0.07,
                    step: 0.0005,
                    format: \.preciseRate,
                    caption: "Coût total des intérêts : \(result.totalInterest.euros)"
                )

                LabeledSlider(
                    title: "Apport",
                    value: $viewModel.input.financing.downPayment,
                    range: viewModel.downPaymentRange,
                    step: 500,
                    format: \.euros,
                    caption: "Montant emprunté : \(result.loanAmount.euros)"
                )

                DisclosureGroup("Charges & fiscalité avancées") {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("État du bien", selection: $viewModel.input.acquisition.condition) {
                            ForEach(PropertyCondition.allCases) { condition in
                                Text("\(condition.label) (\(condition.notaryRate.percent))").tag(condition)
                            }
                        }
                        LabeledSlider(title: "Charges copro non récup.", value: $viewModel.input.operation.monthlyCondoFees,
                                      range: 0...500, step: 5, format: { "\($0.euros)/mois" })
                        LabeledSlider(title: "Taxe foncière", value: $viewModel.input.operation.annualPropertyTax,
                                      range: 0...5_000, step: 50, format: { "\($0.euros)/an" })
                        LabeledSlider(title: "Gestion locative", value: $viewModel.input.operation.managementFeeRate,
                                      range: 0...0.12, step: 0.005, format: \.percent)
                        LabeledSlider(title: "Vacance locative", value: $viewModel.input.operation.vacancyRate,
                                      range: 0...0.25, step: 0.01, format: \.percent)
                        LabeledSlider(title: "Assurance emprunteur", value: $viewModel.input.financing.insuranceRate,
                                      range: 0...0.006, step: 0.0001, format: \.preciseRate)
                        if viewModel.input.taxation.regime.isFurnished {
                            LabeledSlider(title: "Mobilier", value: $viewModel.input.acquisition.furnitureAmount,
                                          range: 0...20_000, step: 500, format: \.euros)
                        }
                    }
                    .padding(.top, 8)
                }

                Button("Réinitialiser aux valeurs de l'annonce", systemImage: "arrow.counterclockwise") {
                    withAnimation { viewModel.resetToListing(profile: profileStore.profile) }
                }
                .font(.subheadline)
            }
        } label: {
            Label("Simulation", systemImage: "slider.horizontal.3")
        }
    }

    private var negotiationCaption: String {
        let rate = viewModel.negotiationRate
        guard abs(rate) >= 0.001 else { return "Prix affiché" }
        return "\(rate < 0 ? "Négociation" : "Surcote") de \(abs(rate).percent) sur le prix affiché"
    }

    private var loanDurationBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.input.financing.durationYears) },
            set: { viewModel.input.financing.durationYears = Int($0.rounded()) }
        )
    }

    // MARK: Coûts, cash-flow, projection

    private var costSection: some View {
        GroupBox {
            CostBreakdownChart(costs: result.costs)
        } label: {
            Label("Coût total de l'opération", systemImage: "chart.pie")
        }
    }

    private var cashflowSection: some View {
        GroupBox {
            CashflowWaterfallView(result: result)
        } label: {
            Label("Décomposition mensuelle", systemImage: "list.bullet.rectangle")
        }
    }

    private var projectionSection: some View {
        GroupBox {
            CashflowProjectionChart(projections: result.projections)
        } label: {
            Label("Cash-flow net-net mensuel par année", systemImage: "chart.bar.xaxis")
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        if !result.warnings.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.warnings) { warning in
                        Label {
                            Text(warning.message).font(.caption)
                        } icon: {
                            Image(systemName: warning.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundStyle(warning.severity == .warning ? Color.orange : Color.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Points d'attention", systemImage: "checklist")
            }
        }
    }

    // MARK: Toolbar & actions

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let listingURL = property.listingURL {
                Button("Voir l'annonce", systemImage: "safari") { openURL(listingURL) }
            }
            Button(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                   systemImage: isFavorite ? "heart.fill" : "heart") {
                toggleFavorite()
            }
            .tint(isFavorite ? .red : nil)
            Button("Enregistrer la simulation", systemImage: "square.and.arrow.down") {
                simulationName = "\(property.city) – \(viewModel.input.taxation.regime.shortLabel)"
                if viewModel.savedSimulationID != nil {
                    saveSimulation()
                } else {
                    isSavePromptPresented = true
                }
            }
        }
    }

    @ViewBuilder
    private var confirmationToast: some View {
        if let confirmationMessage {
            Text(confirmationMessage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { self.confirmationMessage = nil }
                }
        }
    }

    private func toggleFavorite() {
        if let existing = favoriteMatches.first {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteProperty(property: property))
            showConfirmation("Ajouté aux favoris")
        }
    }

    private func saveSimulation() {
        if let id = viewModel.savedSimulationID,
           let existing = try? modelContext.fetch(FetchDescriptor<SavedSimulation>(predicate: #Predicate { $0.id == id })).first {
            existing.update(input: viewModel.input, result: result)
            showConfirmation("Simulation mise à jour")
            return
        }
        let name = simulationName.trimmingCharacters(in: .whitespaces)
        modelContext.insert(SavedSimulation(
            name: name.isEmpty ? property.title : name,
            property: property,
            input: viewModel.input,
            result: result
        ))
        showConfirmation("Simulation enregistrée")
    }

    private func showConfirmation(_ message: String) {
        withAnimation(.snappy) { confirmationMessage = message }
    }
}
