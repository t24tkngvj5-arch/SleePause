# SleepPause

App iOS qui lit une vidéo YouTube et la met en pause automatiquement quand
l'utilisatrice s'endort (détection des yeux fermés via la caméra TrueDepth /
ARKit), en mémorisant le time code exact pour reprendre plus tard.

## Arborescence

```
SleepPause/
├── project.yml          # spec XcodeGen (génère le .xcodeproj dans le CI)
├── codemagic.yaml       # pipeline de build + envoi TestFlight (sans Mac)
└── Sources/
    ├── SleepPauseApp.swift     # point d'entrée @main
    ├── ContentView.swift       # écran principal (assemble lecteur + détecteur)
    ├── YouTubePlayerView.swift # lecteur YouTube IFrame dans une WKWebView
    └── SleepDetector.swift     # détection d'endormissement via ARKit
```

## Prérequis

- Compte Apple Developer Program (99 $/an) — requis pour la signature et TestFlight.
- Un appareil avec Face ID / TrueDepth pour tester la détection (iPhone 13 OK ;
  côté iPad seuls les iPad Pro ont TrueDepth).

## Configuration (à faire une fois)

1. **Bundle id** : remplace `com.antoine.sleeppause` par un identifiant à toi,
   à l'identique dans `project.yml` ET `codemagic.yaml`.
2. **Fiche app** dans App Store Connect avec ce bundle id. Récupère l'« Apple ID »
   numérique de la fiche → variable `APP_STORE_APPLE_ID` dans `codemagic.yaml`.
3. **Clé API App Store Connect** : Users and Access → Integrations → nouvelle clé
   rôle *App Manager*. Télécharge le `.p8`, note *Key ID* et *Issuer ID*.
   Dans Codemagic, crée l'intégration App Store Connect avec ces infos et donne-lui
   le nom utilisé dans `codemagic.yaml` (`ASC_API_KEY`).
4. **Branche ce dépôt sur Codemagic** et lance le workflow `ios-testflight`.
5. **TestFlight** : ajoute-toi comme testeur *interne* → build dispo immédiatement,
   sans revue bêta.

## Réglages de détection

Dans `SleepDetector.swift` :
- `threshold` (8 s) : durée yeux fermés avant de conclure à l'endormissement.
- `closedCutoff` (0.55) : sensibilité de fermeture des yeux.
