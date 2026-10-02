# 🎸 Guitare Tab

PWA mobile (hors-ligne, installable) pour apprendre des chansons à la guitare :
tablatures, accords et paroles avec **défilement automatique**.

## Fonctionnalités
- **Défilement auto** calé sur la durée du morceau (ou estimé selon tempo, mesure et nombre d'accords/mesures), vitesse ajustable (🐢/🐇) et mémorisée par morceau.
- **Ligne de lecture** surlignée, décompte d'une mesure, **métronome** (Web Audio).
- Tap sur la partition = lecture/pause ; défilement manuel possible pendant la lecture.
- **Transposition** des accords (±), **diagrammes d'accords** (formes ouvertes + barrés calculés).
- Tablatures longues **découpées automatiquement** à la largeur de l'écran (coupure sur les barres de mesure).
- Écran maintenu allumé (Wake Lock), taille du texte, thème clair/sombre.
- Pédale Bluetooth / clavier : Espace = lecture, Page↓/→ = avancer, ↑/↓ = vitesse.
- Import : collage ou fichier `.cho`/`.txt` — formats **ChordPro** et **« accords au-dessus des paroles »**. Export/restauration JSON.

## Droits d'auteur
Seuls des morceaux du **domaine public** sont fournis (Au clair de la lune, Amazing Grace, Greensleeves, Oh! Susanna).
Les autres morceaux sont ajoutés par l'utilisateur et stockés uniquement sur son appareil (`localStorage`).

## Utilisation
Servir le dossier en HTTPS (ex. GitHub Pages : `…/guitare/`), ouvrir sur le téléphone puis « Ajouter à l'écran d'accueil ».
