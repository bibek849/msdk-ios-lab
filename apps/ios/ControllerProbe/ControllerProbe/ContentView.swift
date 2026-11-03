import MSDKIOSAppleTransport
import MSDKIOSProbeSupport
import SwiftUI
import UIKit

/// Minimal diagnostic presentation. The app observes only: it has no control,
/// write or network path, and the committed build is BLOCKED.
struct ContentView: View {
    @StateObject private var probe = ExternalAccessoryProbe()
    @State private var cohort = ProbeCohort.unspecified
    @Environment(\.scenePhase) private var scenePhase
    private let profile = ProbeRunProfile(infoDictionary: Bundle.main.infoDictionary ?? [:])

    var body: some View {
        NavigationStack {
            List {
                Section("Build and profile") {
                    LabeledContent("Source", value: profile.sourceSHA ?? "MISSING")
                    LabeledContent("Activation", value: profile.activation.label)
                    LabeledContent("Writes", value: "None; no output stream is opened")
                }
                Section("Run") {
                    Picker("Cohort", selection: $cohort) {
                        Text("Choose").tag(ProbeCohort.unspecified)
                        Text("Cold").tag(ProbeCohort.cold)
                        Text("Primed").tag(ProbeCohort.primed)
                    }
                    Button("Start 60-second run", action: start)
                        .disabled(!canStart)
                    Button("Stop run", role: .destructive) { probe.stop(.operator) }
                        .disabled(!probe.isRunning)
                    if let failure = probe.startFailure {
                        Text("Not started: \(failure)")
                    }
                }
                if let controller = probe.controller {
                    let record = controller.summary(profile: profile)
                    Section("Run record") {
                        Text(record)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy run record") { UIPasteboard.general.string = record }
                    }
                }
                if let accessory = probe.accessoryDescription {
                    Section("Accessory (private inventory; not in the run record)") {
                        LabeledContent("Name", value: accessory.name)
                        LabeledContent("Manufacturer", value: accessory.manufacturer)
                        LabeledContent("Model", value: accessory.modelNumber)
                        LabeledContent("Firmware", value: accessory.firmwareRevision)
                        LabeledContent("Hardware", value: accessory.hardwareRevision)
                        LabeledContent("Protocols", value: accessory.protocolNames.joined(separator: "\n"))
                    }
                }
            }
            .navigationTitle("ControllerProbe")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, probe.isRunning { probe.stop(.appBackground) }
        }
        .onChange(of: probe.isRunning) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running
        }
    }

    private var canStart: Bool {
        !probe.isRunning && cohort != .unspecified && profile.activation.permitsObservation
    }

    private func start() {
        let runID = "run-" + UUID().uuidString.prefix(8).lowercased()
        probe.start(runID: runID, cohort: cohort, activation: profile.activation)
    }
}
