import SwiftUI
import FamilyControls
import ManagedSettings

struct ReminderTrialView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: AppRule?
    @State private var starting = false
    @State private var startTask: Task<Void, Never>?
    @State private var end: Date?
    @State private var issue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Spacer(); CloseButton { dismiss() } }
            Text(selected == nil ? model.voice("Try in an app", "在 App 里试试") : model.voice("Open this app now", "现在打开这个 App"))
                .font(TypeStyle.headline(34))
            Text(model.voice("One-minute preview. Current breaks finish on time.", "试用一分钟。原有休息按时结束。"))
                .font(.custom("AvenirNextCondensed-DemiBold", size: 18))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let selected {
                        Label(selected.token).labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    } else {
                        ForEach(model.rules) { rule in
                            Button { start(rule) } label: {
                                HStack {
                                    Label(rule.token).labelStyle(.titleAndIcon)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.frame(minHeight: 50).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("trial.app." + rule.id)
                            InkRule(weight: 1)
                        }
                    }
                }
            }
            if let issue { Text(issue).font(.callout) }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background { Paper() }.foregroundStyle(Color.ink)
        .presentationDetents([.medium, .large]).disabled(starting)
        .interactiveDismissDisabled(starting)
        .onDisappear { startTask?.cancel(); ReminderTrial.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && selected != nil { dismiss() }
        }
        .task(id: end) {
            guard let end else { return }
            do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) }
            catch { return }
            dismiss()
        }
    }

    private func start(_ rule: AppRule) {
        guard !starting else { return }
        starting = true
        startTask = Task {
            defer { starting = false }
            do {
                end = try await Task.detached { try ReminderTrial.start(rule) }.value
                guard !Task.isCancelled && scenePhase == .active else {
                    ReminderTrial.cancel()
                    dismiss()
                    return
                }
                selected = rule
            } catch { issue = error.localizedDescription }
        }
    }
}
