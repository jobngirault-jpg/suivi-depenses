# ImmoPépite — iOS

Application iOS native (SwiftUI · Swift Data · Swift 6 · iOS 17+) de détection de « pépites » immobilières locatives en France : chaque annonce est simulée financièrement et fiscalement, et reçoit un badge **PÉPITE** lorsque son cash-flow net-net (après impôts et prélèvements sociaux) est positif.

## Lancer le projet

1. Ouvrir `ImmoPepite/ImmoPepite.xcodeproj` avec **Xcode 16 ou plus récent** (le projet utilise les dossiers synchronisés : tout fichier ajouté dans `ImmoPepite/` est compilé automatiquement).
2. Sélectionner l'équipe de signature dans *Signing & Capabilities* (cible `ImmoPepite`).
3. `⌘R` sur un simulateur iOS 17+ ; `⌘U` pour lancer les tests du moteur (Swift Testing).

Sans configuration, l'app fonctionne en **mode démo** (`MockData`, 5 biens).
Pour brancher le backend de scraping, ajouter dans le schéma Xcode (*Edit Scheme › Run › Arguments › Environment Variables*) :

| Variable | Exemple |
|---|---|
| `IMMOPEPITE_API_BASE_URL` | `https://api.mon-backend.fr/` |
| `IMMOPEPITE_API_KEY` | jeton Bearer (optionnel) |

## Architecture (MVVM)

```
ImmoPepite/
├── App/            ImmoPepiteApp (ModelContainer Swift Data), RootTabView
├── Engine/         Moteur de calcul pur, sans dépendance UI
│   ├── FinancialEngine.swift   Orchestration : coûts, crédit, rendements, cash-flows, projection 10 ans
│   ├── LoanCalculator.swift    Mensualité constante + tableau d'amortissement annualisé
│   ├── TaxCalculator.swift     Fiscalité par régime, avec reports (déficits, amortissements différés)
│   ├── FiscalConstants.swift   Barèmes 2026 centralisés (à mettre à jour à chaque LF/LFSS)
│   ├── FiscalRegime.swift      LMNP Réel, Micro-BIC, Foncier Réel, Micro-Foncier, SCI IS, Denormandie
│   └── SimulationInput/Result  Entrées / sorties typées (Codable, Sendable)
├── Models/         Property, Department, SearchFilter, InvestorProfile
│                   @Model FavoriteProperty, @Model SavedSimulation (Swift Data)
├── Services/       PropertyAPIService (+ DTO, MarketEstimator), MockData, DepartmentCatalog
├── ViewModels/     @Observable @MainActor : liste, filtres, détail, profil investisseur
└── Views/          PropertyListView, PropertyCardView, FilterView, PropertyDetailView,
                    SavedPropertiesView, Components/ (chips, FlowLayout, graphiques Swift Charts)
```

## Hypothèses de calcul

- **Frais de notaire** : 7,5 % (ancien) / 2,5 % (neuf) du prix net vendeur, modifiables.
- **Coût total** = prix + agence + notaire + travaux + mobilier (régimes meublés uniquement).
- **Mensualité** = C·t / (1 − (1+t)^−n) + assurance (taux annuel × capital initial / 12).
- **Rendement brut** = loyer annuel / coût total ; **net** = (loyers encaissés − charges) / coût total.
- **Cash-flow brut** = loyer − mensualité ; **net** = loyers encaissés (vacance déduite) − charges − mensualité.
- **Cash-flow net-net** = cash-flow net − fiscalité, **lissé sur 10 ans** pour ne pas surpondérer les effets one-shot (déficit foncier l'année des travaux, frais d'acquisition en SCI IS). La valeur année 1 est affichée à côté.
- **Effort d'épargne** = max(0, −cash-flow net-net).

| Régime | Traitement |
|---|---|
| LMNP Réel | Charges + intérêts déduits ; amortissements bâti (hors terrain 15 %) 30 ans, travaux 15 ans, mobilier 7 ans ; l'amortissement ne crée pas de déficit (report illimité). |
| LMNP Micro-BIC | Abattement 50 %, plafond 77 700 €. |
| Foncier Réel | Travaux déduits l'année 1 ; déficit hors intérêts imputable sur le revenu global ≤ 10 700 €, reliquat reporté sur les revenus fonciers. |
| Micro-Foncier | Abattement 30 %, plafond 15 000 €. |
| SCI à l'IS | IS 15 % ≤ 42 500 € puis 25 % ; frais d'acquisition en charges année 1 ; amortissements ; déficits reportables. Avant distribution. |
| Denormandie | Foncier réel sans déduction des travaux + réduction 12/18/21 % (6/9/12 ans) sur 300 000 € max, si zone éligible et travaux ≥ 25 % du coût total. |

Prélèvements sociaux : 17,2 % (paramétrable dans `TaxationInput`). Les résultats restent des estimations à valider avec un expert-comptable.

## Contrat d'API attendu

`GET /v1/listings?departments=69,38&postal_codes=69007&max_price=150000&limit=50`

```json
{
  "items": [{
    "id": "lbc-123", "source": "leboncoin", "title": "T3 à rénover",
    "property_type": "apartment", "price": 52000, "agency_fees": 0,
    "surface": 62, "rooms": 3, "city": "Saint-Étienne", "postal_code": "42000",
    "image_urls": ["https://…"], "url": "https://…", "description": "…",
    "estimated_rent": 690, "estimated_works": 22000,
    "condo_fees_monthly": 65, "property_tax_yearly": 680,
    "is_new": false, "dpe": "E", "denormandie_zone": false,
    "published_at": "2026-09-20T08:00:00Z"
  }],
  "next_cursor": null
}
```

Les champs d'estimation absents sont complétés par `MarketEstimator` (loyer €/m² par département, travaux selon DPE).
