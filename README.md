# SleepPause

App iOS qui lit une vidéo ou une playlist YouTube et la met en pause
automatiquement quand l'utilisatrice s'endort (détection des yeux fermés via la
caméra TrueDepth / ARKit), puis reprend au réveil. Pensée pour s'endormir devant
une vidéo sans jamais perdre le fil.

## Fonctionnalités
- Endormissement (yeux fermés) → fondu sonore puis pause, time code mémorisé.
- Réveil (yeux rouverts) → retour ~12 s en arrière puis reprise en fondu.
- Baisse de luminosité quand les yeux se ferment ; écran maintenu allumé en lecture.
- Recherche YouTube intégrée + coller un lien (vidéo ou playlist).
- Favoris & récents (avec miniatures), verrou tactile, mode cinéma (plein écran).
- Réglages dans l'app, mot de bonne nuit personnalisé à l'ouverture.
- Statistiques : temps moyen avant endormissement sur la semaine.

## Arborescence
```
SleepPause/
├── .github/workflows/build.yml   # build IPA non signé sur macOS gratuit (GitHub Actions)
├── codemagic.yaml                # build + TestFlight (voie payante, pour plus tard)
├── project.yml                   # spec XcodeGen (génère le .xcodeproj, déclare l'icône)
├── docs/player.html              # lecteur YouTube hébergé sur GitHub Pages (origine https)
└── Sources/
    ├── SleepPauseApp.swift        # point d'entrée @main
    ├── ContentView.swift          # écran principal
    ├── SettingsView.swift         # réglages + statistiques
    ├── Store.swift                # config (URL) + état persistant (réglages, favoris, journal)
    ├── YouTubePlayerView.swift    # lecteur IFrame (WKWebView) + contrôleur
    ├── YouTubeSearch.swift        # recherche via YouTube Data API
    ├── SleepDetector.swift        # détection endormissement / réveil (ARKit)
    └── Assets.xcassets/           # icône de l'app
```

## Prérequis
- Appareil avec Face ID / TrueDepth pour la détection (iPhone 13 OK ; côté iPad,
  seuls les iPad Pro ont TrueDepth — sinon le lecteur marche mais pas la détection).
- Dépôt **public** sur GitHub (minutes macOS gratuites + GitHub Pages).

## Mise en route — voie gratuite, sans Mac
1. **GitHub Pages** : Settings → Pages → branche `main`, dossier `/docs`. Vérifie
   que `https://<pseudo>.github.io/<repo>/player.html` affiche un écran noir.
   ⚠️ Cette URL doit correspondre à `Config.playerPageURL` dans `Sources/Store.swift`.
2. **Clé API YouTube** (pour la recherche) : sur Google Cloud, active *YouTube Data
   API v3*, crée une clé API, restreins-la à cette API, puis ajoute-la en **secret
   GitHub** nommé `YT_API_KEY` (Settings → Secrets and variables → Actions).
3. **Build & install** : push → onglet *Actions* → télécharge l'artefact IPA →
   installe avec **Sideloadly** (Apple ID gratuit). Active le **Mode développeur**
   sur l'appareil (une seule fois). À re-signer tous les 7 jours.

## Voie payante — pour livrer à quelqu'un (ni 7 jours, ni Mode développeur)
Compte Apple Developer (99 €/an) + Codemagic (`codemagic.yaml`) → TestFlight.

## Réglages (écran ⚙️, valeurs par défaut dans Sources/Store.swift)
- `sleepThreshold` (8 s) : durée yeux fermés avant l'endormissement.
- `wakeThreshold` (3 s) : durée yeux ouverts avant le réveil.
- `sensitivity` (0.55) : seuil de fermeture des yeux (plus bas = plus réactif).
- `rewindSeconds` (12 s) : retour en arrière au réveil.
- Fondu sonore, baisse de luminosité, écran allumé, prénom (mot de bonne nuit).
