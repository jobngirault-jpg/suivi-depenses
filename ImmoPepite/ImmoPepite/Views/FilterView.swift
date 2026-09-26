import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(InvestorProfileStore.self) private var profileStore

    @State private var viewModel: FilterViewModel
    private let onApply: (SearchFilter) -> Void

    init(filter: SearchFilter, onApply: @escaping (SearchFilter) -> Void) {
        _viewModel = State(initialValue: FilterViewModel(filter: filter))
        self.onApply = onApply
    }

    var body: some View {
        @Bindable var profileStore = profileStore

        NavigationStack {
            Form {
                departmentsSection
                citiesSection
                financialSection
                investorSection(profile: $profileStore.profile)
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        onApply(viewModel.draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Réinitialiser les filtres", role: .destructive) {
                        viewModel.reset()
                    }
                }
            }
        }
    }

    // MARK: Départements

    private var departmentsSection: some View {
        Section {
            FlowLayout {
                ForEach(viewModel.departments) { department in
                    ChipView(title: department.label, isSelected: viewModel.isSelected(department)) {
                        withAnimation(.snappy) { viewModel.toggle(department) }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Départements")
        } footer: {
            Text("Aucune sélection = toute la France.")
        }
    }

    // MARK: Villes

    @ViewBuilder
    private var citiesSection: some View {
        let selectedDepartments = viewModel.selectedDepartments
        if !selectedDepartments.isEmpty {
            Section {
                if !viewModel.selectedCityTags.isEmpty {
                    FlowLayout {
                        ForEach(viewModel.selectedCityTags) { city in
                            ChipView(title: city.label, isSelected: true, showsRemoveIcon: true) {
                                withAnimation(.snappy) { viewModel.toggle(city) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                TextField("Rechercher une ville ou un code postal", text: $viewModel.citySearchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                ForEach(selectedDepartments) { department in
                    let cities = viewModel.availableCities(in: department)
                    if !cities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(department.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            FlowLayout {
                                ForEach(cities) { city in
                                    ChipView(title: city.label, isSelected: viewModel.isSelected(city)) {
                                        withAnimation(.snappy) { viewModel.toggle(city) }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Villes & codes postaux")
            } footer: {
                Text("Sans ville sélectionnée, tout le département est inclus.")
            }
        }
    }

    // MARK: Critères financiers

    private var financialSection: some View {
        Section("Rentabilité") {
            Toggle("Uniquement les pépites", isOn: $viewModel.draft.onlyPepites)

            Toggle("Rendement brut minimum", isOn: $viewModel.isMinYieldEnabled)
            if viewModel.isMinYieldEnabled {
                LabeledSlider(
                    title: "Rendement ≥",
                    value: $viewModel.minYield,
                    range: 0.03...0.20,
                    step: 0.005,
                    format: \.percent
                )
            }

            Toggle("Cash-flow net-net minimum", isOn: $viewModel.isMinCashflowEnabled)
            if viewModel.isMinCashflowEnabled {
                LabeledSlider(
                    title: "Cash-flow ≥",
                    value: $viewModel.minCashflow,
                    range: -500...1_000,
                    step: 10,
                    format: { "\($0.signedEuros)/mois" }
                )
            }

            Toggle("Prix maximum", isOn: $viewModel.isMaxPriceEnabled)
            if viewModel.isMaxPriceEnabled {
                LabeledSlider(
                    title: "Prix ≤",
                    value: $viewModel.maxPrice,
                    range: 30_000...800_000,
                    step: 5_000,
                    format: \.euros
                )
            }
        }
    }

    // MARK: Hypothèses investisseur

    private func investorSection(profile: Binding<InvestorProfile>) -> some View {
        Section {
            Picker("Régime fiscal", selection: profile.preferredRegime) {
                ForEach(FiscalRegime.allCases) { regime in
                    Text(regime.label).tag(regime)
                }
            }
            Picker("TMI", selection: profile.marginalTaxRate) {
                ForEach(FiscalConstants.marginalTaxRates, id: \.self) { rate in
                    Text(rate.formatted(.percent)).tag(rate)
                }
            }
            LabeledSlider(title: "Apport", value: profile.downPaymentRate, range: 0...0.5, step: 0.01, format: \.percent,
                          caption: "En % du coût total de l'opération")
            LabeledSlider(title: "Taux d'emprunt", value: profile.loanRate, range: 0.01...0.07, step: 0.0005, format: \.preciseRate)
            Picker("Durée du prêt", selection: profile.loanDurationYears) {
                ForEach(InvestorProfile.loanDurations, id: \.self) { years in
                    Text("\(years) ans").tag(years)
                }
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "Assurance emprunteur", value: profile.insuranceRate, range: 0...0.006, step: 0.0001, format: \.preciseRate)
            LabeledSlider(title: "Gestion locative", value: profile.managementFeeRate, range: 0...0.12, step: 0.005, format: \.percent)
            LabeledSlider(title: "Vacance locative", value: profile.vacancyRate, range: 0...0.2, step: 0.01, format: \.percent)
        } header: {
            Text("Mes hypothèses")
        } footer: {
            Text("Utilisées pour calculer le cash-flow de chaque annonce et attribuer le badge PÉPITE.")
        }
    }
}
