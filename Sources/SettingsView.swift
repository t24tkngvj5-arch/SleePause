import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Détection") {
                    sliderRow("Endormissement", $app.sleepThreshold, 3...20, "s")
                    sliderRow("Réveil", $app.wakeThreshold, 1...6, "s")
                    VStack(alignment: .leading) {
                        Text("Sensibilité des yeux : \(String(format: "%.2f", app.sensitivity))")
                        Slider(value: $app.sensitivity, in: 0.30...0.80)
                        Text("Plus bas = détecte plus vite les yeux fermés")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("Lecture") {
                    sliderRow("Retour au réveil", $app.rewindSeconds, 0...30, "s")
                    Toggle("Fondu sonore avant la pause", isOn: $app.fadeEnabled)
                    Toggle("Baisser la luminosité", isOn: $app.dimEnabled)
                    Toggle("Garder l'écran allumé", isOn: $app.keepAwake)
                }
                Section("Sommeil") {
                    if let avg = app.weeklyAverageMinutes {
                        Label("Cette semaine : endormie après \(Int(avg.rounded())) min en moyenne",
                              systemImage: "moon.zzz.fill")
                    } else {
                        Text("Pas encore de données cette semaine.").foregroundColor(.secondary)
                    }
                    ForEach(app.sleepLog.suffix(5).reversed()) { e in
                        HStack {
                            Text(e.date, style: .date)
                            Spacer()
                            Text("\(Int(e.minutes.rounded())) min").foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Réglages")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }

    private func sliderRow(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ unit: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(label) : \(Int(value.wrappedValue.rounded())) \(unit)")
            Slider(value: value, in: range)
        }
    }
}
