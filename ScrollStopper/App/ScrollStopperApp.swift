import SwiftUI

@main
struct ScrollStopperApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).environment(\.locale, Locale(identifier: model.language.code))
                .tint(.ink)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var reveal: DuckRevealRequest?
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var usageProbePresented = false
    #endif
    var body: some View {
        Group {
            if let reveal {
                DuckComicReveal(voice: model.voice, edition: reveal.edition) { self.reveal = nil }
            } else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--usage-probe") { UsageProbeView() }
            else if !model.onboarded { WelcomeView() }
            else { HomeView() }
            #else
            if !model.onboarded { WelcomeView() }
            else { HomeView() }
            #endif
            }
        }
        .preferredColorScheme(reveal?.edition == 0 ? .dark : .light)
        .sheet(isPresented: $model.showSetup) { SetupView() }
        .sheet(isPresented: $model.showSettings) { SettingsView() }
        .fullScreenCover(item: $model.interruption) { mode in InterruptionView(preview: mode.preview, initialMood: mode.mood) }
        .onAppear { ReminderTrial.cancel(); receiveReveal() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { ReminderTrial.cancel(); receiveReveal(); model.refresh() }
            if phase == .background { model.firstDutyThisVisit = false }
        }
        .onOpenURL { url in
            #if DEBUG
            if url.host == "usage-probe" { usageProbePresented = true; return }
            #endif
            model.refresh()
        }
        #if DEBUG
        .sheet(isPresented: $usageProbePresented) { UsageProbeView() }
        #endif
        .task(id: model.session.cooldownUntil) {
            guard let deadline = model.session.cooldownUntil else { return }
            let delay = max(0, deadline.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            model.refresh()
        }
    }
    private func receiveReveal() {
        #if DEBUG && targetEnvironment(simulator)
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--qa-edition-") }), let n = Int(arg.suffix(1)), (0...2).contains(n) {
            reveal = DuckRevealRequest(edition: n, created: Date()); return
        }
        #endif
        guard let request = DuckRevealRequest.consume() else { return }
        model.showSettings = false
        model.showSetup = false
        model.interruption = nil
        reveal = request
    }

}
