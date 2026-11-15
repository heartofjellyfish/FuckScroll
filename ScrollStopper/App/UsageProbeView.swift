#if DEBUG
import SwiftUI
import FamilyControls

struct UsageProbeView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var picker = false
    @State private var status = "Records timing only. No blocking."
    @State private var count = 0
    @State private var busy = false
    @State private var recording = false
    var body: some View {
        NavigationStack {
            Form {
                Section("No-Shortcuts experiment") {
                    Text(status)
                    Text("Use the selected app directly on your iPhone for 2 minutes, then return here.")
                        .font(.subheadline)
                    TimelineView(.periodic(from: .now, by: 2)) { _ in
                        let thresholds = Set(UsageProbe.entries.filter { $0.kind == "threshold" }.compactMap(\.usageSeconds))
                        HStack {
                            Label("1 min", systemImage: thresholds.contains(60) ? "checkmark.circle.fill" : "circle")
                            Spacer()
                            Label("2 min", systemImage: thresholds.contains(120) ? "checkmark.circle.fill" : "circle")
                        }.accessibilityIdentifier("probe.checkpoints")
                    }
                    Button("1. Allow Screen Time") {
                        Task { do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                            status = "Screen Time allowed."
                        } catch { status = error.localizedDescription } }
                    }
                    Button("2. Select one test app") { picker = true }.disabled(busy || recording)
                    Button("3. Start recording") {
                        guard selection.applicationTokens.count == 1,
                              selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty,
                              let token = selection.applicationTokens.first else {
                            status = "Choose exactly one app, no categories or websites."
                            return
                        }
                        busy = true
                        status = "Registering with iOS…"
                        Task {
                            do {
                                try await Task.detached { try UsageProbe.start(token: token) }.value
                                recording = true
                                status = "Recording. Open the selected app."
                            } catch { status = error.localizedDescription }
                            busy = false
                        }
                    }.disabled(busy || recording)
                    Text("Selected: \(selection.applicationTokens.count) app(s)")
                    if let token = selection.applicationTokens.first { Label(token).labelStyle(.titleAndIcon) }
                }
                Section("Test marks") {
                    Button("Mark: about to open target") { UsageProbe.record("operator-open-next") }
                    Button("Mark: returned from target") { UsageProbe.record("operator-left-target") }
                    Button("Refresh log") { count = UsageProbe.entries.count; UsageProbe.exportSnapshot() }
                    Text("\(count) entries saved on this phone.")
                    Button("Stop recording") {
                        busy = true
                        Task {
                            await Task.detached { UsageProbe.stop() }.value
                            recording = false
                            busy = false
                            status = "Stopped."
                        }
                    }.disabled(busy)
                }
                Section("System delivery log") {
                    TimelineView(.periodic(from: .now, by: 3)) { _ in
                        let entries = UsageProbe.entries
                        Text("Usage callbacks: \(entries.filter { $0.kind == "threshold" }.count)")
                        ForEach(Array(entries.suffix(20).enumerated()), id: \.offset) { _, entry in
                            Text("\(entry.time.formatted(date: .omitted, time: .standard)) · \(entry.kind)\(entry.usageSeconds.map { " · \($0)s" } ?? "")")
                                .font(.caption.monospaced())
                        }
                    }
                    if let url = UsageProbe.url {
                        ShareLink("Export local log", item: url)
                    }
                }
            }
            .navigationTitle("Usage probe")
            .onAppear {
                if let rule = SharedStore.rules.first { selection.applicationTokens = [rule.token] }
                UsageProbe.exportSnapshot()
            }
            .familyActivityPicker(isPresented: $picker, selection: $selection)
        }
    }
}
#endif
