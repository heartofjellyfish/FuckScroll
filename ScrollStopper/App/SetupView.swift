import SwiftUI
import FamilyControls
import ManagedSettings

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pose: DuckPose?
    @State private var replayBeat = false
    private var settledPose: DuckPose { pose ?? restingPose }
    @State private var playback = 0
    @State private var previousEdit: (field: String, index: Int, from: Int)?
    @State private var showPicker = false
    @State private var showCustomTime = false
    @State private var customTimeText = ""
    @State private var customTimeTitle = ""
    @State private var customTimeToken: ApplicationToken?
    @State private var customTimeName = ""
    @State private var customIsUsage = true
    @State private var applyCustomTime: ((Int) -> Void)?
    @Environment(\.dynamicTypeSize) private var sizeCategory
    @State private var order: [ApplicationToken] = []
    private var tokens: [ApplicationToken] { order.filter { model.selection.applicationTokens.contains($0) } }
    #if DEBUG && targetEnvironment(simulator)
    @State private var exampleLimit = [ProcessInfo.processInfo.arguments.contains("--qa-first-selection") ? 20 : 5,10,20,15,5,30,10,5,20]
    private var sampleCount: Int {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--qa-first-selection") { return 1 }
        if args.contains("--qa-nine") { return 9 }
        if args.contains("--qa-store-market") {
            return min(9, max(1, UserDefaults.standard.integer(forKey: "qaStoreExampleCount")))
        }
        return args.contains("--qa-three") ? 3 : 2
    }
    @State private var exampleRest = [15,5,15,10,5,15,5,10,5]
    private var exampleNames: [String] {
        let fallback = ["rednote","Instagram","Discord","Drums","Photos","Maps","Notes","Reminders","Calendar"]
        guard ProcessInfo.processInfo.arguments.contains("--qa-store-market") else { return fallback }
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: folder.appendingPathComponent("qa-app-names.json")),
              let names = try? JSONDecoder().decode([String].self, from: data), names.count == fallback.count else { return fallback }
        return names
    }
    #endif
    private var sample: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--qa-limits")
        #else
        return false
        #endif
    }
    private var hasSelection: Bool { sample || !model.selection.applicationTokens.isEmpty }
    private var needsAccess: Bool { !model.authorized && !sample }
    var body: some View {
        VStack(spacing: 0) {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text(model.voice("YOUR LIMITS.", "你的限度。").replacingOccurrences(of: "YOUR LIMITS.", with: "YOUR\nLIMITS."))
                            .font(TypeStyle.headline(57)).lineSpacing(-13).lineLimit(3).minimumScaleFactor(0.55)
                            .accessibilityAddTraits(.isHeader).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 22).padding(.bottom, 8)
                        Button {
                            playback += 1
                        } label: {
                            Image((replayBeat && !reduceMotion ? (settledPose == .look ? .specs : .look) : settledPose).rawValue)
                                .resizable().scaledToFit().frame(maxWidth: 158)
                                .contentShape(Rectangle())
                        }.disabled(reduceMotion)
                            .accessibilityLabel(model.voice("Replay duck reaction", "重播鸭子表情"))
                            .accessibilityIdentifier("setup.replayDuck")
                    }
                    Rectangle().fill(Color.ink).frame(height: 3)
                    if needsAccess || !hasSelection {
                        Text(needsAccess
                             ? model.voice("Screen Time lets the duck pause the apps you pick.", "授权屏幕使用时间，鸭子就能在到点时拦住你选的 App。")
                             : model.voice("Pick the apps you lose time to.", "选出那些让你一刷就忘了时间的 App。"))
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 22, relativeTo: .body))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.vertical, 22)
                    } else {
                        Section {
                            ForEach(Array(tokens.enumerated()), id: \.element) { index, token in
                                row(index, resting: model.state(for: token).isResting(at: Date()),
                                    usage: Binding(get: { model.limits[token] ?? 20 }, set: { model.limits[token] = $0 }),
                                    rest: Binding(get: { model.breaks[token] ?? 15 }, set: { model.breaks[token] = $0 })) {
                                    Label(token).labelStyle(.titleAndIcon)
                                }.id(token)
                            }
                            #if DEBUG && targetEnvironment(simulator)
                            if sample {
                                ForEach(0..<sampleCount, id: \.self) { i in
                                    row(i, resting: i == 0 && ProcessInfo.processInfo.arguments.contains("--qa-locked"),
                                        usage: $exampleLimit[i], rest: $exampleRest[i]) {
                                        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                                           let img = UIImage(contentsOfFile: url.appendingPathComponent("qa-icon-\(i).png").path) {
                                            Image(uiImage: img).resizable().frame(width: 28,height: 28)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        Text(exampleNames[i])
                                    }
                                }
                            }
                            #endif
                        } header: { headings }
                    }
                }
            }
            .onAppear { syncOrder(); if let focus = model.focusedToken { reader.scrollTo(focus, anchor: .center) } }
            .onChange(of: model.selection.applicationTokens) { _, _ in
                previousEdit = nil
                pose = nil
                syncOrder()
            }
        }
            VStack(spacing: 8) {
                InkRule(variant: 2, weight: 1.15).padding(.horizontal, 22)
                if !hasSelection || needsAccess {
                    InkButton(title: hasSelection ? model.voice("Allow Screen Time", "允许屏幕使用时间") : model.voice("Select apps", "选择 App"), disabled: model.authorizing) {
                        Task {
                            if needsAccess { await model.requestAccess() }
                            if model.authorized && !hasSelection { showPicker = true }
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 8)
                        .accessibilityIdentifier(hasSelection ? "setup.authorize" : "setup.selectApp")
                } else {
                    HStack(spacing: 18) {
                        Button { showPicker = true } label: {
                            Text(model.voice("Change apps", "增删 App"))
                                .font(.custom("AvenirNextCondensed-DemiBold", size: 20))
                                .padding(.bottom, 4)
                                .overlay(alignment: .bottom) {
                                    Underline().stroke(Color.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                                        .frame(height: 4).accessibilityHidden(true)
                                }
                                .frame(minHeight: 44)
                        }.disabled(!model.authorized && !sample).accessibilityIdentifier("setup.selectApp")
                        Button { model.save() } label: {
                            HStack {
                                Text(model.saving ? model.voice("Starting…", "启动中…") : ((model.enabled || sample) && model.onboarded ? model.voice("Save changes", "保存修改") : model.voice("Put the duck on duty", "让鸭子上班")))
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.right").font(.body)
                            }.font(TypeStyle.headline(22)).padding(.horizontal, 16).frame(minHeight: 54)
                                .foregroundStyle(Color.paper).background(Color.ink, in: RoundedRectangle(cornerRadius: 7))
                        }.accessibilityIdentifier("setup.save").disabled(!sample && (!model.authorized || tokens.isEmpty))
                    }.padding(.horizontal, 24).padding(.bottom, 8)
                }
            }.background(Color.paper).fixedSize(horizontal: false, vertical: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack { Spacer(); CloseButton { dismiss() } }.padding(.trailing, 12).background(Color.paper)
        }
        .buttonStyle(.plain).background { Paper() }.foregroundStyle(Color.ink)
        .disabled(model.saving).interactiveDismissDisabled(model.saving)
            .task(id: playback) {
                guard playback > 0, !reduceMotion else { return }
                replayBeat = true
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    replayBeat = false
                } catch { return }
            }
            .sheet(isPresented: $showCustomTime, onDismiss: { applyCustomTime = nil }) {
                NegotiationTimeView(title: customTimeTitle, token: customTimeToken, appName: customTimeName,
                                    isUsage: customIsUsage, text: $customTimeText) { minutes in
                    applyCustomTime?(minutes)
                    showCustomTime = false
                }
                .environmentObject(model)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.paper)
            }
            .familyActivityPicker(
                headerText: model.voice("Open a category and pick individual apps.", "展开分类，逐个选择 App。"),
                isPresented: $showPicker, selection: $model.selection
            )
            .onChange(of: model.selection) { _, _ in
                // The picker can publish its final selection after dismissing.
                if !showPicker { finishPicking() }
            }
            .onChange(of: showPicker) { _, open in
                if !open { finishPicking() }
            }
            .alert(model.voice("Check your selection", "检查所选项目"), isPresented: Binding(
                get: { model.selectionIssue != nil },
                set: { if !$0 { model.selectionIssue = nil } }
            ), presenting: model.selectionIssue) { issue in
                if issue == .unsupportedItems && !model.selection.applicationTokens.isEmpty {
                    Button(model.voice("Keep selected apps", "保留已选 App")) { model.keepSelectedApps() }
                }
                Button(model.voice("Change apps", "增删 App")) { showPicker = true }
                Button(model.voice("Cancel", "取消"), role: .cancel) {}
            } message: { issue in
                Text(issue.message(model.voice))
            }
            .alert(model.voice("Something didn’t stick.", "刚才没设好。"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button(model.voice("Got it", "知道了"), role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
    }
    private func finishPicking() {
        guard model.checkSelection() else { return }
        // With no rows there is no Save button: commit an explicit clear now.
        model.saveEmptySelectionIfNeeded()
    }
    // A persistent expression follows current settings, including previously saved rules.
    private var restingPose: DuckPose {
        #if DEBUG && targetEnvironment(simulator)
        if sample {
            return (0..<sampleCount).contains { DuckPose.isLenient(use: exampleLimit[$0], rest: exampleRest[$0]) } ? .look : .writing
        }
        #endif
        return model.selection.applicationTokens.contains { token in
            DuckPose.isLenient(use: model.limits[token] ?? 20, rest: model.breaks[token] ?? 15)
        } ? .look : .writing
    }
    private let chipWidth: CGFloat = 79
    private var usageTitle: String { model.voice("Use for", "使用上限") }
    private var restTitle: String { model.voice("Break for", "休息时长") }

    private var headings: some View {
        HStack(spacing: 8) {
            Text(model.voice("Apps", "App")).font(TypeStyle.headline(21))
            Spacer(minLength: 0)
            if !sizeCategory.isAccessibilitySize {
                ForEach([usageTitle, restTitle], id: \.self) { title in
                    Text(title).frame(width: chipWidth).multilineTextAlignment(.center)
                }
            }
        }.font(.custom("AvenirNextCondensed-DemiBold", size: 17))
            .padding(.vertical, 14).overlay(alignment: .bottom) { InkRule(variant: 0, weight: 1.35) }.padding(.horizontal, 22)
            .background(Color.paper)
    }

    private func row<L: View>(_ index: Int, resting: Bool, usage: Binding<Int>, rest: Binding<Int>,
                              @ViewBuilder label: () -> L) -> some View {
        let stacked = sizeCategory.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { label() }.font(.custom("AvenirNextCondensed-DemiBold", size: 20, relativeTo: .body))
                if resting { Text(model.voice("Next round", "下一轮")).font(TypeStyle.label(12)) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                timeChip(usageTitle, id: "usage", index: index, value: usage, choices: ScrollPolicy.minuteOptions)
                timeChip(restTitle, id: "rest", index: index, value: rest, choices: [1,5,10,15,20,30,60])
            }
        }.padding(.vertical, 12).frame(minHeight: 77)
            .overlay(alignment: .bottom) { InkRule(variant: index + 1, weight: 0.9) }.padding(.horizontal, 22)
    }

    private func timeChip(_ field: String, id: String, index: Int, value: Binding<Int>, choices: [Int]) -> some View {
        let number = String(value.wrappedValue)
        let formatted = model.voice.minutes(value.wrappedValue)
        var styled = AttributedString(formatted)
        if let range = styled.range(of: number) { styled[range].font = TypeStyle.headline(24) }
        let update: (Int) -> Void = { next in
                    let old = value.wrappedValue
                    guard next != old else { return }
                    let wasLenient = restingPose == .look
                    let before = settledPose
                    value.wrappedValue = next
                    let undoing = previousEdit?.field == id && previousEdit?.index == index && previousEdit?.from == next
                    replayBeat = false
                    playback = 0
                    if restingPose == .look {
                        // Keep eye contact, but acknowledge every new choice with a different still.
                        pose = before == .look ? .specs : .look
                    } else if wasLenient {
                        pose = .writing
                    } else {
                        pose = before.next(change: next - old, usage: id == "usage", undoing: undoing)
                    }
                    previousEdit = (id, index, old)
        }
        let availableChoices = Array(Set(choices + [value.wrappedValue])).sorted()
        return VStack(spacing: 2) {
            if sizeCategory.isAccessibilitySize { Text(field).font(.caption) }
            Menu {
                Picker(field, selection: Binding(get: { value.wrappedValue }, set: update)) {
                    ForEach(availableChoices, id: \.self) { Text(model.voice.minutes($0)).tag($0) }
                }
                Button(model.voice("Custom", "自定义")) {
                    customTimeTitle = field
                    customIsUsage = id == "usage"
                    customTimeToken = tokens.indices.contains(index) ? tokens[index] : nil
                    customTimeName = ""
                    #if DEBUG && targetEnvironment(simulator)
                    if sample { customTimeName = exampleNames[index] }
                    #endif
                    customTimeText = String(value.wrappedValue)
                    applyCustomTime = update
                    showCustomTime = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text(styled).font(.custom("AvenirNextCondensed-DemiBold", size: 15)).lineLimit(1).minimumScaleFactor(0.75)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }.frame(width: chipWidth, height: 43)
                    .background { RoundedRectangle(cornerRadius: 5).fill(Color.duckYellow).shadow(color: .ink, radius: 0, x: 1, y: 2) }
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.ink, lineWidth: 1.5))
                    .frame(minHeight: 46)
            }.accessibilityLabel(field).accessibilityValue(formatted).accessibilityIdentifier("setup." + id + ".\(index)")
        }
    }

    private func syncOrder() {
        let selected = model.selection.applicationTokens
        order = order.filter { selected.contains($0) }
        for rule in model.rules where selected.contains(rule.token) && !order.contains(rule.token) { order.append(rule.token) }
        for token in selected where !order.contains(token) { order.append(token) }
    }
}


private enum DuckPose: String {
    case writing = "LimitsDuck", specs = "LimitsSpecs", approve = "LimitsApprove"
    case look = "DuckLibrary03", erase = "LimitsErase"

    static func isLenient(use: Int, rest: Int) -> Bool {
        use >= 30 || (use >= 20 && rest <= 5)
    }

    func next(change: Int, usage: Bool, undoing: Bool) -> Self {
        if undoing { return self == .erase ? .specs : .erase }
        let extraScroll = usage ? change : -change
        if extraScroll >= 30 { return self == .erase ? .look : .erase }
        if extraScroll >= 15 { return self == .look ? .specs : .look }
        if extraScroll > 0 { return self == .specs ? .look : .specs }
        return self == .approve ? .specs : .approve
    }
}

/// Draft-only editor: Deal updates the limits form; its Save changes still commits the rules.
private struct NegotiationTimeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let title: String
    let token: ApplicationToken?
    let appName: String
    let isUsage: Bool
    @Binding var text: String
    let apply: (Int) -> Void
    @FocusState private var editing: Bool
    private var minutes: Int? {
        guard let n = Int(text), (1...120).contains(n) else { return nil }
        return n
    }
    private var watching: Bool {
        guard let n = minutes else { return false }
        return isUsage ? n >= 30 : n <= 5
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Image(watching ? "DuckLibrary03" : "LimitsDuck")
                    .resizable().scaledToFit().frame(width: 145, height: 112)
                    .accessibilityHidden(true)
            }.padding(.trailing, 18).padding(.bottom, -6)
            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    if let token { Label(token).labelStyle(.titleAndIcon).lineLimit(1) }
                    else if !appName.isEmpty { Text(appName).lineLimit(1) }
                    Text("· " + title).fixedSize()
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .heavy))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(model.voice("Cancel", "取消"))
                        .accessibilityIdentifier("customTime.cancel")
                }.font(.custom("AvenirNextCondensed-DemiBold", size: 19))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $text)
                        .font(TypeStyle.headline(76)).multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad).focused($editing)
                        .frame(width: 145).tint(Color.ink)
                        .accessibilityLabel(model.voice("Minutes", "分钟"))
                        .accessibilityIdentifier("customTime.input")
                    Text(model.voice("min", "分钟")).font(TypeStyle.note(25))
                    Button { editing = true } label: {
                        Image(systemName: "pencil").font(.system(size: 28, weight: .medium))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(model.voice("Edit minutes", "修改分钟数"))
                }
                .overlay(alignment: .bottom) {
                    Underline().stroke(Color.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .frame(width: 190, height: 5).offset(y: 4)
                }
                Text(model.voice("1–120 minutes", "1–120 分钟"))
                    .font(.custom("AvenirNextCondensed-DemiBold", size: 17))
                    .padding(.top, 4)
                HStack {
                    Text(model.voice("Your offer.", "你开个价。"))
                        .font(TypeStyle.note(19))
                    Spacer()
                    Button {
                        guard let minutes else { return }
                        apply(minutes)
                    } label: {
                        HStack(spacing: 12) {
                            Text(model.voice("Deal.", "成交。"))
                            Image(systemName: "checkmark").font(.system(size: 20, weight: .bold))
                        }.font(TypeStyle.headline(26))
                            .padding(.horizontal, 22).frame(height: 50)
                            .foregroundStyle(Color.paper)
                            .background(Color.ink.opacity(minutes == nil ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 6))
                    }.disabled(minutes == nil).accessibilityIdentifier("customTime.deal")
                }.padding(.top, 3)
            }
            .padding(.horizontal, 18).padding(.bottom, 18).padding(.top, 7)
            .background {
                RoundedRectangle(cornerRadius: 9).fill(Color.duckYellow)
                    .shadow(color: Color.ink, radius: 0, x: 1, y: 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.ink, lineWidth: 1.7))
        }
        .padding(.horizontal, 15).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .foregroundStyle(Color.ink).buttonStyle(.plain)
        .task { editing = true }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard let field = note.object as? UITextField else { return }
            DispatchQueue.main.async { field.selectAll(nil) }
        }
        .onChange(of: text) { _, value in
            let clean = String(value.filter { $0.isASCII && $0.isNumber }.prefix(3))
            if clean != value { text = clean }
        }
    }
}
