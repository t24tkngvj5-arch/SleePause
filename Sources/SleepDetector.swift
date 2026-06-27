import ARKit

// Détecte l'endormissement (yeux fermés assez longtemps) ET le réveil
// (yeux rouverts assez longtemps), via la caméra TrueDepth.
final class SleepDetector: NSObject, ObservableObject, ARSessionDelegate {

    @Published var eyesClosed = false
    @Published var isAsleep   = false

    let isSupported = ARFaceTrackingConfiguration.isSupported

    /// Yeux fermés en continu pendant ce temps -> endormie.
    var sleepThreshold: TimeInterval = 8.0
    /// Yeux rouverts en continu pendant ce temps -> réveillée.
    var wakeThreshold: TimeInterval = 1.5
    /// Seuil au-dessus duquel un œil est compté comme fermé (0…1).
    var closedCutoff: Float = 0.55

    var onAsleep: (() -> Void)?   // appelé une fois quand elle s'endort
    var onWake:   (() -> Void)?   // appelé une fois quand elle se réveille

    private let session = ARSession()
    private var closedSince: Date?
    private var openSince: Date?
    private var asleep = false     // état interne (thread ARKit)

    func start() {
        guard isSupported else { return }
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
        reset()
    }

    /// À appeler quand on change de vidéo, pour repartir d'un état propre.
    func reset() {
        closedSince = nil
        openSince = nil
        asleep = false
        DispatchQueue.main.async {
            self.isAsleep = false
            self.eyesClosed = false
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        let left  = face.blendShapes[.eyeBlinkLeft]?.floatValue  ?? 0
        let right = face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        let closed = (left > closedCutoff) && (right > closedCutoff)

        DispatchQueue.main.async { self.eyesClosed = closed }

        if closed {
            openSince = nil
            if closedSince == nil { closedSince = Date() }
            if !asleep, let since = closedSince,
               Date().timeIntervalSince(since) >= sleepThreshold {
                asleep = true
                DispatchQueue.main.async {
                    self.isAsleep = true
                    self.onAsleep?()
                }
            }
        } else {
            closedSince = nil
            if openSince == nil { openSince = Date() }
            if asleep, let since = openSince,
               Date().timeIntervalSince(since) >= wakeThreshold {
                asleep = false
                DispatchQueue.main.async {
                    self.isAsleep = false
                    self.onWake?()
                }
            }
        }
    }
}
