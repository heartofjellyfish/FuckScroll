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
    @State private var timeMenu: TimeMenu?
    @State private var showCustomTime = false
    @AppStorage("customTimeNextFoldedPose") private var nextFoldedPose = false
    @State private var customDuckAsset = "CustomDuckThinking"
    @State private var customTimeText = ""
    @State private var customTimeTitle = ""
    @State private var customTimeToken: ApplicationToken?
    @State private var customTimeIcon: UIImage?
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
                            .opacity(showCustomTime ? 0 : 1)
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
                                    usage: Binding(get: { model.limits[token] ?? ScrollPolicy.defaultUsage }, set: { model.limits[token] = $0 }),
                                    rest: Binding(get: { model.breaks[token] ?? ScrollPolicy.defaultBreak }, set: { model.breaks[token] = $0 })) {
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
            HStack { Spacer(); CloseButton { dismiss() }
                .opacity(showCustomTime ? 0 : 1)
                .allowsHitTesting(!showCustomTime)
            }.padding(.trailing, 12).background(Color.paper)
        }
        .accessibilityHidden(timeMenu != nil || showCustomTime)
        .overlayPreferenceValue(TimeChipBounds.self) { anchors in
            if let menu = timeMenu, let anchor = anchors[menu.id] {
                GeometryReader { geometry in
                    timeDropdown(menu, anchor: geometry[anchor], size: geometry.size)
                }
            }
        }
        .buttonStyle(.plain).background { Paper() }.foregroundStyle(Color.ink)
        .blur(radius: showCustomTime ? 5 : 0)
        .disabled(model.saving).interactiveDismissDisabled(model.saving)
            .task(id: playback) {
                guard playback > 0, !reduceMotion else { return }
                replayBeat = true
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    replayBeat = false
                } catch { return }
            }
            .overlay {
                if showCustomTime {
                    NegotiationTimeView(title: customTimeTitle, duckAsset: customDuckAsset, token: customTimeToken, exampleIcon: customTimeIcon,
                                        text: $customTimeText, cancel: {
                        showCustomTime = false
                        applyCustomTime = nil
                    }) { minutes in
                        applyCustomTime?(minutes)
                        showCustomTime = false
                        applyCustomTime = nil
                    }
                    .environmentObject(model)
                    .accessibilityAddTraits(.isModal)
                }
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
            DuckPose.isLenient(use: model.limits[token] ?? ScrollPolicy.defaultUsage, rest: model.breaks[token] ?? ScrollPolicy.defaultBreak)
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
                timeChip(restTitle, id: "rest", index: index, value: rest, choices: ScrollPolicy.breakOptions)
            }
        }.padding(.vertical, 12).frame(minHeight: 77)
            .overlay(alignment: .bottom) { InkRule(variant: index + 1, weight: 0.9) }.padding(.horizontal, 22)
    }

    private func timeChip(_ field: String, id: String, index: Int, value: Binding<Int>, choices: [Int]) -> some View {
        let formatted = model.voice.duration(value.wrappedValue)
        let styled = durationLabel(value.wrappedValue, numberSize: value.wrappedValue >= 60 ? 20 : 24, unitSize: 14)
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
            let chipID = "setup." + id + ".\(index)"
            Button {
                timeMenu = TimeMenu(id: chipID, title: field, selected: value.wrappedValue, choices: availableChoices) { minutes in
                    timeMenu = nil
                    update(minutes)
                } custom: {
                    timeMenu = nil
                    customTimeTitle = field
                    customTimeToken = tokens.indices.contains(index) ? tokens[index] : nil
                    customTimeIcon = nil
                    #if DEBUG && targetEnvironment(simulator)
                    if sample, let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        customTimeIcon = UIImage(contentsOfFile: folder.appendingPathComponent("qa-icon-\(index).png").path)
                    }
                    #endif
                    customTimeText = String(value.wrappedValue)
                    applyCustomTime = update
                    customDuckAsset = nextFoldedPose ? "CustomDuckFolded" : "CustomDuckThinking"
                    nextFoldedPose.toggle()
                    showCustomTime = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text(styled).font(.custom("AvenirNextCondensed-DemiBold", size: 15)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }.frame(width: chipWidth, height: 43)
                    .background { RoundedRectangle(cornerRadius: 5).fill(Color.duckYellow).shadow(color: .ink, radius: 0, x: 1, y: 2) }
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.ink, lineWidth: 1.5))
                    .frame(minHeight: 46)
            }
            .accessibilityLabel(field).accessibilityValue(formatted).accessibilityIdentifier(chipID)
            .anchorPreference(key: TimeChipBounds.self, value: .bounds) { [chipID: $0] }
        }
    }

    private func durationLabel(_ minutes: Int, numberSize: CGFloat, unitSize: CGFloat) -> AttributedString {
        var label = AttributedString()
        for character in model.voice.duration(minutes) {
            var part = AttributedString(String(character))
            part.font = character.isNumber ? TypeStyle.headline(numberSize)
                : .custom("AvenirNextCondensed-DemiBold", size: unitSize)
            label += part
        }
        return label
    }

    private func timeDropdown(_ menu: TimeMenu, anchor: CGRect, size: CGSize) -> some View {
        let margin: CGFloat = 12
        let gap: CGFloat = 6
        let width = min(size.width - 2 * margin, sizeCategory.isAccessibilitySize ? 270 : 184)
        let availableHeight = max(0, size.height - 2 * margin)
        let x = max(margin, min(anchor.maxX - width, size.width - margin - width))
        let rowHeight: CGFloat = sizeCategory.isAccessibilitySize ? 60 : 44
        let desiredHeight = CGFloat(menu.choices.count) * rowHeight + 96
        let height = min(desiredHeight, availableHeight)
        let below = anchor.maxY + gap
        let above = anchor.minY - gap - height
        let y = below + height <= size.height - margin ? below
            : above >= margin ? above
            : max(margin, min(below, size.height - margin - height))

        return ZStack(alignment: .topLeading) {
            Color.ink.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture { timeMenu = nil }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(menu.title)
                    .font(TypeStyle.label(12))
                    .foregroundStyle(Color.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .accessibilityAddTraits(.isHeader)
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(menu.choices, id: \.self) { minutes in
                                let selected = minutes == menu.selected
                                Button { menu.select(minutes) } label: {
                                    HStack {
                                        Text(durationLabel(minutes, numberSize: 23, unitSize: 16))
                                        Spacer(minLength: 6)
                                        if selected {
                                            Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy))
                                        }
                                    }
                                    .padding(.horizontal, 10).frame(minHeight: rowHeight)
                                    .background {
                                        if selected {
                                            RoundedRectangle(cornerRadius: 3).fill(Color.duckYellow)
                                                .padding(.vertical, 4)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .accessibilityAddTraits(selected ? .isSelected : [])
                                .id(minutes)
                            }
                        }
                    }
                    .onAppear { reader.scrollTo(menu.selected, anchor: .center) }
                }
                InkRule(variant: 2, weight: 1)
                Button(action: menu.custom) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil").font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(model.voice("Custom", "自定义"))
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 19, relativeTo: .body))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
            .padding(6)
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: 6).fill(Color.paper)
                    .shadow(color: .ink, radius: 0, x: 3, y: 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ink, lineWidth: 1.6))
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { timeMenu = nil }
            .offset(x: x, y: y)
        }
    }

    private func syncOrder() {
        let selected = model.selection.applicationTokens
        order = order.filter { selected.contains($0) }
        for rule in model.rules where selected.contains(rule.token) && !order.contains(rule.token) { order.append(rule.token) }
        for token in selected where !order.contains(token) { order.append(token) }
    }
}


private struct TimeMenu {
    let id: String
    let title: String
    let selected: Int
    let choices: [Int]
    let select: (Int) -> Void
    let custom: () -> Void
}

private struct TimeChipBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
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
    let title: String
    let duckAsset: String
    let token: ApplicationToken?
    let exampleIcon: UIImage?
    @Binding var text: String
    let cancel: () -> Void
    let apply: (Int) -> Void
    @State private var hours = 0
    @State private var minutes = 0
    @State private var inputError: String?
    private var total: Int { hours * 60 + minutes }
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            Color.ink.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 6)
                Image(duckAsset)
                    .resizable().scaledToFit()
                    .frame(width: min(geometry.size.width * 0.60, geometry.size.height * 0.32),
                           height: min(geometry.size.width * 0.60, geometry.size.height * 0.32), alignment: .bottom)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, -25)
                    .zIndex(1)
                    .allowsHitTesting(false).accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if let token {
                        Label(token).labelStyle(.iconOnly).fixedSize().frame(width: 28, height: 28)
                    } else if let exampleIcon {
                        Image(uiImage: exampleIcon).resizable().scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true)
                    }
                    Text(title).lineLimit(1).minimumScaleFactor(0.8)
                }.font(.custom("AvenirNextCondensed-DemiBold", size: 21))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(alignment: .trailing) {
                    Button(action: cancel) {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .heavy))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(model.voice("Cancel", "取消"))
                        .accessibilityIdentifier("customTime.cancel")
                }

                HStack(spacing: 16) {
                    Text(model.voice("Hours", "小时")).frame(maxWidth: .infinity)
                    Text(model.voice("Minutes", "分钟")).frame(maxWidth: .infinity)
                }
                .font(.custom("AvenirNextCondensed-DemiBold", size: 18))
                .padding(.horizontal, 20).padding(.top, 4)

                HStack(spacing: 16) {
                    PaperTimeWheel(value: $hours, values: 0...24,
                                   label: model.voice("Hours", "小时"), identifier: "customTime.hours")
                    PaperTimeWheel(value: $minutes, values: 0...59,
                                   label: model.voice("Minutes", "分钟"), identifier: "customTime.minutes")
                        .disabled(hours == 24).opacity(hours == 24 ? 0.35 : 1)
                }
                .padding(.horizontal, 20)
                .background(alignment: .center) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.duckYellow).frame(height: 52)
                        .overlay(alignment: .top) { InkRule(variant: 1, weight: 1) }
                        .overlay(alignment: .bottom) { InkRule(variant: 2, weight: 1) }
                }

                VStack(spacing: 8) {
                    if let inputError {
                        Text(inputError).font(.custom("AvenirNextCondensed-DemiBold", size: 16))
                            .foregroundStyle(Color(red: 0.65, green: 0.16, blue: 0.12))
                            .accessibilityIdentifier("customTime.error")
                    }
                    Button {
                        guard ScrollPolicy.minuteRange.contains(total) else {
                            inputError = model.voice("Choose 1 minute to 24 hours.", "请选择 1 分钟至 24 小时。")
                            return
                        }
                        text = String(total)
                        apply(total)
                    } label: {
                        HStack(spacing: 7) {
                            Text(model.voice("Deal", "成交")).font(TypeStyle.headline(24))
                            DuckFootSignature()
                                .frame(width: 26, height: 26).rotationEffect(.degrees(-10))
                                .accessibilityHidden(true)
                        }.frame(width: 135, height: 50)
                            .foregroundStyle(Color.paper)
                            .background(Color.ink, in: RoundedRectangle(cornerRadius: 6))
                    }.accessibilityLabel(model.voice("Deal", "成交"))
                        .accessibilityIdentifier("customTime.deal")
                }.padding(.top, 12)
            }
            .padding(.horizontal, 18).padding(.bottom, 18).padding(.top, 20)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.ink, lineWidth: 1.7))
            .background {
                RoundedRectangle(cornerRadius: 9).fill(Color.ink).offset(x: 1, y: 3)
            }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 15).padding(.bottom, 10)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundStyle(Color.ink).buttonStyle(.plain)
        .accessibilityAction(.escape, cancel)
        .onAppear {
            let initial = Int(text) ?? 0
            hours = initial / 60
            minutes = initial % 60
        }
        .onChange(of: hours) { _, next in
            if next == 24 { minutes = 0 }
        }
        .onChange(of: total) { _, _ in inputError = nil }
    }
}

private struct PaperTimeWheel: View {
    @Binding var value: Int
    let values: ClosedRange<Int>
    let label: String
    let identifier: String
    @State private var position: Int?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(values), id: \.self) { number in
                    Text(String(number))
                        .font(TypeStyle.headline(number == value ? 45 : 30))
                        .foregroundStyle(Color.ink.opacity(number == value ? 1 : abs(number - value) == 1 ? 0.4 : 0.16))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEnabled else { return }
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { position = number }
                        }
                        .id(number)
                }
            }.scrollTargetLayout()
        }
        .safeAreaPadding(.vertical, 96)
        .scrollIndicators(.hidden)
        .scrollDisabled(!isEnabled)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .frame(height: 240)
        .onAppear { position = value }
        .onChange(of: position) { _, next in
            if isEnabled, let next { value = next }
        }
        .onChange(of: value) { _, next in
            if position != next { position = next }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label).accessibilityValue(String(value))
        .accessibilityIdentifier(identifier)
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: value = min(values.upperBound, value + 1)
            case .decrement: value = max(values.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}
