import Foundation

/// Barèmes fiscaux France (revenus 2026) centralisés pour une mise à jour annuelle
/// après chaque Loi de Finances / LFSS. Toutes les valeurs sont des fractions (0.172 = 17,2 %).
enum FiscalConstants {
    // MARK: Prélèvements sociaux
    /// CSG + CRDS + prélèvement de solidarité sur revenus du patrimoine (fonciers / LMNP).
    static let socialContributionsRate = 0.172

    // MARK: Micro-BIC (LMNP location meublée longue durée, non classée)
    static let microBICAllowance = 0.50
    static let microBICCeiling = 77_700.0

    // MARK: Micro-foncier (location nue)
    static let microFoncierAllowance = 0.30
    static let microFoncierCeiling = 15_000.0

    // MARK: Foncier réel
    /// Plafond d'imputation du déficit foncier (hors intérêts) sur le revenu global.
    static let landDeficitGlobalCeiling = 10_700.0
    /// Forfait de frais de gestion déductible par local (ligne 221 de la 2044).
    static let foncierFlatManagementAllowance = 20.0

    // MARK: Impôt sur les sociétés
    static let corporateReducedRate = 0.15
    static let corporateReducedRateThreshold = 42_500.0
    static let corporateStandardRate = 0.25

    // MARK: Denormandie (prorogé jusqu'au 31/12/2027)
    static let denormandieBaseCeiling = 300_000.0
    static let denormandieMinimumWorksRatio = 0.25
    static let taxNicheCeiling = 10_000.0

    // MARK: Amortissements (LMNP réel / SCI IS)
    static let defaultLandShare = 0.15
    static let buildingDepreciationYears = 30
    static let worksDepreciationYears = 15
    static let furnitureDepreciationYears = 7

    // MARK: Frais de notaire estimés
    static let notaryRateOld = 0.075
    static let notaryRateNew = 0.025

    /// Tranches marginales d'imposition (barème IR).
    static let marginalTaxRates: [Double] = [0, 0.11, 0.30, 0.41, 0.45]
}
