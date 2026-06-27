# SleepPause

App iOS qui lit une vidéo YouTube et la met en pause automatiquement quand
l'utilisatrice s'endort (détection des yeux fermés via la caméra TrueDepth /
ARKit), en mémorisant le time code exact pour reprendre plus tard.

## Arborescence

```
SleepPause/
├── .github/workflows/build.yml  # build IPA non signé sur macOS gratuit (GitHub Actions)
├── project.yml                  # spec XcodeGen (génère le .xcodeproj)
├── codemagic.yaml               # build + TestFlight (voie payante, pour plus tard)
└── Sources/
    ├── SleepPauseApp.swift       # point d'entrée @main
    ├── ContentView.swift         # écran principal
    ├── YouTubePlayerView.swift   # lecteur YouTube IFrame (WKWebView)
    └── SleepDetector.swift       # détection d'endormissement (ARKit)
```

## Deux façons de faire tourner l'app

### Option A — GRATUITE, sans Mac (pour développer/tester sur SON iPhone)
1. Dépôt **public** sur GitHub → GitHub Actions compile un IPA non signé (`build.yml`).
2. Récupère l'IPA dans l'onglet **Actions → artefacts**.
3. Installe-le avec **Sideloadly** (Windows, gratuit) + un **Apple ID gratuit** + iPhone en USB.
4. App valable 7 jours, à re-signer ensuite (démon auto Sideloadly). Limite : 3 apps.
   → N'atteint que ton propre iPhone, pas un appareil distant.

### Option B — PAYANTE (99 €/an), pour livrer à quelqu'un d'autre via TestFlight
1. Apple Developer Program + fiche app dans App Store Connect.
2. Clé API App Store Connect → intégration Codemagic (nom = `ASC_API_KEY`).
3. Codemagic lit `codemagic.yaml`, build + envoi TestFlight, installation sans câble à distance.

## Réglages de détection (Sources/SleepDetector.swift)
- `threshold` (8 s) : durée yeux fermés avant de conclure à l'endormissement.
- `closedCutoff` (0.55) : sensibilité de fermeture des yeux.

## Prérequis matériel
Appareil avec Face ID / TrueDepth pour la détection (iPhone 13 OK ;
côté iPad, seuls les iPad Pro ont TrueDepth).
