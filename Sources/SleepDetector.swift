import ARKit

// MARK: - Détecteur d'endormissement
// Lance une ARSession de suivi du visage (caméra avant TrueDepth, fonctionne
// dans le noir grâce à l'IR de Face ID) SANS afficher la caméra. On lit en
// continu les blendshapes eyeBlinkLeft / eyeBlinkRight (0 = ouvert, ~1 = fermé)
// et on considère qu'elle dort quand les deux yeux restent fermés > `threshold`.
//
// Note : pas de @MainActor ici car ARKit appelle le delegate sur sa propre file ;
// on repasse sur le main pour toute mise à jour @Published / callback.
final class SleepDetector: NSObject, ObservableObject, ARSessionDelegate {

    @Published var eyesClosed = false
    @Published var isAsleep   = false

    /// Disponible seulement sur appareils à caméra TrueDepth (iPhone X+).
    let isSupported = ARFaceTrackingConfiguration.isSupported

    /// Durée pendant laquelle les yeux doivent rester fermés avant de conclure
    /// à l'endormissement (un clignement normal dure < 0,4 s).
    var threshold: TimeInterval = 8.0

    /// Seuil au-dessus duquel un œil est compté comme « fermé ».
    var closedCutoff: Float = 0.55

    /// Appelé une fois quand l'endormissement est détecté.
    var onAsleep: (() -> Void)?

    private let session = ARSession()
    private var closedSince: Date?
    private var fired = false   // évite de redéclencher tant qu'on n'a pas réarmé

    func start() {
        guard isSupported else { return }
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
        closedSince = nil
        fired = false
        DispatchQueue.main.async {
            self.isAsleep = false
            self.eyesClosed = false
        }
    }

    /// À appeler après avoir repris la vidéo, pour pouvoir redétecter un
    /// nouvel endormissement.
    func rearm() {
        closedSince = nil
        fired = false
        DispatchQueue.main.async { self.isAsleep = false }
    }

    // MARK: ARSessionDelegate
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        let left  = face.blendShapes[.eyeBlinkLeft]?.floatValue  ?? 0
        let right = face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        let closed = (left > closedCutoff) && (right > closedCutoff)

        DispatchQueue.main.async { self.eyesClosed = closed }

        if closed {
            if closedSince == nil { closedSince = Date() }
            if let since = closedSince,
               Date().timeIntervalSince(since) >= threshold,
               !fired {
                fired = true
                DispatchQueue.main.async {
                    self.isAsleep = true
                    self.onAsleep?()
                }
            }
        } else {
            closedSince = nil   // yeux rouverts : on remet le compteur à zéro
        }
    }
}
