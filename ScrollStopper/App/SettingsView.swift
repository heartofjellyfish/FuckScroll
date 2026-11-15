import SwiftUI
import CoreText
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var preview = false
    @State private var trial = false
    @State private var keyboardTop: CGFloat?
    private var canTryShield: Bool { model.authorized && !model.rules.isEmpty && !model.isSimulator }
    @State private var showRules = false
    @State private var showLanguages = false
    @AppStorage(SharedStore.reminderKey, store: SharedStore.defaults) private var reminder = ""
    @AppStorage(SharedStore.actionKey, store: SharedStore.defaults) private var actionText = ""
    @State private var showReminder = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var editing: ReminderPart?
    private var onDuty: Bool { model.dutyStatus == .on }
    var body: some View {
        GeometryReader { viewport in
        let rowHeight: CGFloat = 64
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Spacer(); CloseButton { dismiss() } }.padding(.horizontal, 12).padding(.top, 8)
                galleryHeader(width: viewport.size.width)
                InkRule(weight: 1.5).padding(.horizontal, 24)
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        sectionNumber("01")
                        VStack(alignment: .leading, spacing: 0) {
                    if model.dutyStatus == .check {
                        Button {
                            if model.authorized { model.retryDuty() }
                            else {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.edit() }
                            }
                        } label: {
                            HStack {
                                Text(model.dutyLabel).font(TypeStyle.headline(22))
                                Spacer()
                                Text(model.authorized ? model.voice("Retry", "重试") : model.voice("Allow Screen Time", "允许屏幕使用时间"))
                                    .font(TypeStyle.headline(18)).underline()
                            }.frame(minHeight: rowHeight).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(model.saving).accessibilityIdentifier("settings.retryDuty")
                        if model.enabled && model.authorized {
                            Button(model.voice("Pause limits", "暂停限时")) { model.setDuty(false) }
                                .font(TypeStyle.headline(18)).frame(minHeight: 44).disabled(model.saving)
                        }
                    } else {
                        Toggle(isOn: Binding(get: { onDuty }, set: { requested in
                            if !model.isRehearsal && (!model.authorized || model.rules.isEmpty) {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.edit() }
                            } else { model.setDuty(requested) }
                        })) { Text(model.dutyStatus == .starting ? model.dutyLabel : model.voice("Duck on duty", "鸭子值班")).font(TypeStyle.headline(22)) }
                            .toggleStyle(.switch).tint(.green)
                            .frame(minHeight: rowHeight).disabled(model.saving).accessibilityIdentifier("settings.pause")
                    }
                        }
                    }
                    }.padding(.horizontal, 4).frame(minHeight: rowHeight)
                        .background(Color.duckYellow, in: RoundedRectangle(cornerRadius: 3))
                        .padding(.top, 18).padding(.bottom, 5)
                    sectionHeader(model.voice("How it works", "使用说明"), number: "02", expanded: showRules, height: rowHeight) { showRules.toggle() }
                        .accessibilityIdentifier("settings.help")
                    if showRules {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([
                                model.voice("Each app adds up visits and locks at its limit.", "每个 App 单独累计，用满就锁。"),
                                model.voice("Stay away for a full break to reset usage.", "提前离开满休息时长，用时清零。"),
                                model.voice("Usage resets after a break or at midnight.", "休息结束或到午夜，用时清零。"),
                                model.voice("Close the duck. Limits still work.", "关掉鸭子，限时照常。")
                            ], id: \.self) { rule in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•").accessibilityHidden(true)
                                    Text(rule).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 18, relativeTo: .body))
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                    }
                    if let issue = model.session.monitoringError { Text(issue).font(.footnote).foregroundStyle(Color.mutedInk) }
                    InkRule(variant: 2, weight: 1.3)
                    sectionHeader(model.voice("Edit break screen", "自定义休息提醒"), number: "03", expanded: showReminder, height: rowHeight) {
                        editing = nil
                        showReminder.toggle()
                    }.accessibilityIdentifier("settings.reminder")
                    if showReminder {
                        VStack(spacing: 10) {
                            ReminderFace(voice: model.voice, miniature: true,
                                         message: $reminder, action: $actionText, focus: $editing, keyboardTop: keyboardTop, proceed: {})
                                .aspectRatio(UIScreen.main.bounds.width / UIScreen.main.bounds.height, contentMode: .fit)
                                .frame(maxWidth: min(245, UIScreen.main.bounds.width * 0.58))
                                .clipShape(RoundedRectangle(cornerRadius: 17))
                                .padding(.trailing, 8)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .overlayPreferenceValue(ReminderTextBounds.self) { bounds in
                                    ReminderInk(bounds: bounds, voice: model.voice)
                                        .allowsHitTesting(false).accessibilityHidden(true)
                                }
                            Button {
                                editing = nil
                                if canTryShield { trial = true } else { preview = true }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption.bold())
                                    Text(canTryShield ? model.voice("Try in an app", "在 App 里试试") : model.voice("Layout preview", "预览排版")).font(TypeStyle.headline(19))
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain).accessibilityIdentifier("settings.preview")
                        }.frame(maxWidth: .infinity)
                        .padding(.bottom, editing == .action ? keyboardTop.map { max(0, UIScreen.main.bounds.height - $0) } ?? 0 : 0)
                        .id("reminderCard")
                        .onAppear {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                                scroll.scrollTo("reminderCard", anchor: .bottom)
                            }
                        }
                        .task(id: editing) {
                            let part = editing
                            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                scroll.scrollTo("reminderCard", anchor: part == .message ? .top : .bottom)
                            }
                        }
                    }
                    InkRule(variant: 3, weight: 1.3)
                    sectionHeader(model.voice("Language", "语言"), number: "04", detail: model.language.title, expanded: showLanguages, height: rowHeight) {
                        editing = nil
                        showLanguages.toggle()
                    }.accessibilityIdentifier("settings.language")
                    if showLanguages {
                        VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Button {
                                model.language = language
                                showLanguages = false
                            } label: {
                                HStack {
                                    Text(language.title).font(TypeStyle.label(17))
                                    Spacer()
                                    if model.language == language {
                                        Image(systemName: "checkmark").font(.body.bold())
                                    }
                                }.frame(minHeight: 44).padding(.horizontal, 8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(model.language == language ? .isSelected : [])
                        }
                        }.id("languageChoices")
                        .onAppear {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                                scroll.scrollTo("languageChoices", anchor: .bottom)
                            }
                        }
                    }
                    galleryManifesto.padding(.top, 32)
                    if model.resting {
                        Text(model.voice("Current breaks finish on time.", "本轮休息仍按原时间结束。"))
                            .font(TypeStyle.label(12)).foregroundStyle(Color.mutedInk).padding(.top, 12)
                    }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        }
        }.scrollDismissesKeyboard(.interactively).scrollBounceBehavior(.basedOnSize).background { Paper() }.foregroundStyle(Color.ink)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                keyboardTop = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.minY
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardTop = nil }
            .presentationDetents([.large])
            .sheet(isPresented: $trial) { ReminderTrialView() }
            .fullScreenCover(isPresented: $preview) { ReminderPreview(voice: model.voice) }
            .alert(model.voice("Couldn’t start.", "没启动成功。"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
    }
    private func galleryHeader(width: CGFloat) -> some View {
        let scale = width / 393
        return ZStack(alignment: .topLeading) {
            Circle().fill(Color.duckYellow)
                .frame(width: 193 * scale, height: 193 * scale)
                .offset(x: 231 * scale, y: 8 * scale)
            GroundRulesTitle(title: model.voice("GROUND\nRULES.", "把话\n说明白。"))
                .frame(width: 181 * scale, height: 112 * scale)
                .offset(x: 26 * scale, y: 39 * scale)
            Image(onDuty ? "GroundRulesDuck" : "GroundRulesOff")
                .resizable().scaledToFit().frame(width: 211 * scale)
                .offset(x: 169 * scale, y: 37 * scale)
                .accessibilityHidden(true)
        }.frame(width: width, height: 204 * scale, alignment: .topLeading).clipped()
    }
    private func sectionNumber(_ number: String) -> some View {
        Text(number).font(.custom("AvenirNextCondensed-DemiBold", size: 13, relativeTo: .caption))
            .foregroundStyle(Color.mutedInk).frame(width: 21, alignment: .leading).accessibilityHidden(true)
    }
    private var galleryManifesto: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle().fill(Color.duckYellow).frame(width: 4, height: 94).padding(.top, 9)
            VStack(alignment: .leading, spacing: 8) {
                Text(model.voice("MY PHONE.\nMY TERMS.", "我的手机。\n我的规矩。"))
                    .font(TypeStyle.headline(39)).lineSpacing(-5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.voice("Signed, the duck.", "签字：鸭子。"))
                    .font(TypeStyle.note(16)).foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func sectionHeader(_ title: String, number: String, detail: String? = nil, expanded: Bool, height: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                sectionNumber(number)
                Text(title).font(TypeStyle.headline(22)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let detail { Text(detail).font(TypeStyle.label(16)).foregroundStyle(Color.mutedInk) }
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14, weight: .heavy)).frame(width: 16)
            }.padding(.horizontal, 4).frame(minHeight: height).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityValue(expanded ? model.voice("Expanded", "已展开") : model.voice("Collapsed", "已收起"))
    }
}

// Place the first and last ink bounds against the illustration's top and baseline.
private struct GroundRulesTitle: View {
    let title: String
    var body: some View {
        Canvas { context, size in
            let font = UIFont(name: "AvenirNextCondensed-Heavy", size: 68) ?? UIFont.boldSystemFont(ofSize: 68)
            let lines = title.components(separatedBy: "\n").map {
                CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: UIColor(Color.ink)]))
            }
            let bounds = lines.map { CTLineGetBoundsWithOptions($0, .useGlyphPathBounds) }
            let verticalScale = (size.height - 4 - CGFloat(lines.count - 1) * 6) / max(1, bounds.reduce(0) { $0 + $1.height })
            let scale = min(verticalScale, size.width / max(1, bounds.map(\.width).max() ?? 1))
            context.withCGContext { cg in
                for (index, line) in lines.enumerated() {
                    let box = bounds[index]
                    let blockHeight = bounds.reduce(CGFloat(0)) { $0 + $1.height * scale } + CGFloat(lines.count - 1) * 6
                    let top = (size.height - blockHeight) / 2 + bounds.prefix(index).reduce(CGFloat(0)) { $0 + $1.height * scale + 6 }
                    cg.saveGState()
                    cg.translateBy(x: -box.minX * scale, y: top + box.maxY * scale)
                    cg.scaleBy(x: scale, y: -scale)
                    cg.textPosition = .zero
                    CTLineDraw(line, cg)
                    cg.restoreGState()
                }
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityAddTraits(.isHeader)
    }
}

private enum ReminderPart { case message, action }

private struct ReminderTextBounds: PreferenceKey {
    static var defaultValue: [ReminderPart: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [ReminderPart: Anchor<CGRect>], nextValue: () -> [ReminderPart: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct ReminderInk: View {
    let bounds: [ReminderPart: Anchor<CGRect>]
    let voice: Voice
    private let red = Color(red: 0.89, green: 0.20, blue: 0.14)

    var body: some View {
        GeometryReader { geo in
            if let msg = bounds[.message], let act = bounds[.action] {
                let message = geo[msg], action = geo[act]
                let cardWidth = min(245, UIScreen.main.bounds.width * 0.58, geo.size.width - 8)
                let margin = max(42, geo.size.width - cardWidth - 14)
                let ring = action.insetBy(dx: -6, dy: -5)
                note(voice("Note to yourself", "写给自己"), width: margin, above: message.midY - 27, color: .mutedInk)
                note(voice("Your exit button", "收手按钮"), width: margin, above: ring.midY - 31, color: red)
                Canvas { ctx, _ in
                    func arrow(from start: CGPoint, to end: CGPoint, color: Color, weight: CGFloat) {
                        var path = Path()
                        path.move(to: start)
                        path.addQuadCurve(to: end, control: CGPoint(x: start.x + 9, y: end.y + 11))
                        path.move(to: CGPoint(x: end.x - 10, y: end.y - 4))
                        path.addLine(to: end)
                        path.addLine(to: CGPoint(x: end.x - 8, y: end.y + 7))
                        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round))
                    }
                    arrow(from: CGPoint(x: margin * 0.48, y: message.midY - 27),
                          to: CGPoint(x: message.minX - 4, y: message.midY), color: Color(red: 0.59, green: 0.53, blue: 0.43), weight: 1.5)
                    arrow(from: CGPoint(x: margin * 0.41, y: ring.midY - 31),
                          to: CGPoint(x: ring.minX - 2, y: ring.midY + 1), color: red, weight: 2.7)
                    // Draw a loose loop around the measured text block, including its wrapped lines.
                    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                        CGPoint(x: ring.minX + x * ring.width, y: ring.minY + y * ring.height)
                    }
                    var loop = Path()
                    // Begin above the oval. The returning nib crosses that first stroke.
                    let crossing = point(0.77, 0.05)
                    loop.move(to: CGPoint(x: crossing.x + 6, y: crossing.y + 4))
                    loop.addQuadCurve(to: CGPoint(x: crossing.x - 5, y: crossing.y - 3),
                                      control: crossing)
                    loop.addQuadCurve(to: point(0.33, 0.02), control: point(0.52, -0.11))
                    loop.addCurve(to: point(0, 0.56), control1: point(0.14, 0.07), control2: point(-0.01, 0.28))
                    loop.addCurve(to: point(0.56, 0.98), control1: point(0.015, 0.92), control2: point(0.28, 1.08))
                    loop.addCurve(to: point(1, 0.44), control1: point(0.82, 0.95), control2: point(1.03, 0.77))
                    loop.addQuadCurve(to: crossing, control: point(1.00, 0.15))
                    loop.addLine(to: CGPoint(x: crossing.x - 6, y: crossing.y + 2))
                    ctx.stroke(loop, with: .color(red), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
    }
    private func note(_ title: String, width: CGFloat, above startY: CGFloat, color: Color) -> some View {
        Text(title).font(.custom("Noteworthy-Bold", size: 18)).foregroundStyle(color)
            .multilineTextAlignment(.leading).lineLimit(3).minimumScaleFactor(0.75)
            .frame(width: width, alignment: .leading).rotationEffect(.degrees(-7))
            .frame(height: max(0, startY - 13), alignment: .bottom)
            .position(x: width / 2, y: max(0, startY - 13) / 2)
    }
}

private struct ReminderFace: View {
    let voice: Voice
    let miniature: Bool
    @Binding var message: String
    @Binding var action: String
    let focus: FocusState<ReminderPart?>.Binding
    var keyboardTop: CGFloat? = nil
    let proceed: () -> Void
    @State private var draft: [ReminderPart: String] = [:]

    var body: some View {
        GeometryReader { box in
            let w = box.size.width, h = box.size.height
            ZStack {
                Color(uiColor: BreakScreen.renderedBackground)
                let scale = w / UIScreen.main.bounds.width
                Image(BreakScreen.eye).resizable().scaledToFit()
                    .frame(width: 80 * scale, height: 80 * scale)
                    .position(x: w / 2, y: h * 0.244)
                control(.message, width: w).position(x: w / 2, y: h * 0.315)
                control(.action, width: w).position(x: w / 2, y: h * 0.875)
            }
        }.foregroundStyle(Color.paper)
    }
    private func control(_ part: ReminderPart, width: CGFloat) -> some View {
        let isAction = part == .action
        let fallback = SharedStore.reminderLine("", action: isAction, voice: voice)
        let stored = isAction ? $action : $message
        let display = SharedStore.reminderLine(stored.wrappedValue, action: isAction, voice: voice)
        let limit = isAction ? SharedStore.actionLimit : SharedStore.reminderLimit
        let scale = width / UIScreen.main.bounds.width
        let pointSize = UIFontMetrics(forTextStyle: isAction ? .body : .title2).scaledValue(for: isAction ? 17 : 22)
        let font = Font.system(size: pointSize * scale, weight: isAction ? .semibold : .bold)
        let controlWidth = isAction ? min(168 * scale, width) : width * 0.88
        let inset = isAction ? 18 * scale : 0
        let active = miniature && focus.wrappedValue == part
        let label = Text(display).font(font).lineLimit(isAction ? nil : 4)
            .fixedSize(horizontal: false, vertical: true)

        // One measured label sizes the editor, the white capsule and the ink loop.
        // The keyboard and character counter never change that geometry.
        return label
            .overlay(alignment: .trailing) {
                if miniature && !active && !isAction {
                    Image(systemName: "pencil").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.duckYellow).offset(x: 16).accessibilityHidden(true)
                }
            }
            .anchorPreference(key: ReminderTextBounds.self, value: .bounds) { isAction ? [:] : [part: $0] }
            .frame(width: max(1, controlWidth - inset * 2))
            .opacity(active ? 0 : 1)
            .overlay {
                if miniature {
                    TextField(fallback, text: Binding(get: { draft[part] ?? stored.wrappedValue }, set: { input in
                        if input.contains(where: { $0.isNewline }) { focus.wrappedValue = nil }
                        let clean = SharedStore.limitedReminder(input.trimmingCharacters(in: .newlines), limit: limit)
                        draft[part] = input
                        stored.wrappedValue = clean
                        if input != clean {
                            DispatchQueue.main.async {
                                if draft[part] == input { draft[part] = clean }
                            }
                        }
                    }), axis: .vertical)
                        .focused(focus, equals: part)
                        .font(font).multilineTextAlignment(.center)
                        .tint(isAction ? Color.ink : .duckYellow)
                        .scrollDisabled(true).submitLabel(.done)
                        .onSubmit { focus.wrappedValue = nil }
                        .accessibilityIdentifier(isAction ? "settings.actionText" : "settings.reminderText")
                        .opacity(active ? 1 : 0).allowsHitTesting(active).accessibilityHidden(!active)
                        .onChange(of: active) { _, editing in if !editing { draft[part] = nil } }
                }
            }
            .padding(.horizontal, inset)
            .padding(.vertical, (isAction ? 10 : 5) * scale)
            .frame(minHeight: isAction ? 50 * scale : 0)
            .background {
                if isAction { Capsule().fill(Color(uiColor: BreakScreen.actionBackground)) }
            }
            .transformAnchorPreference(key: ReminderTextBounds.self, value: .bounds) { values, anchor in
                if isAction { values[part] = anchor }
            }
            .overlay(alignment: .trailing) {
                if miniature && !active && isAction {
                    Image(systemName: "pencil").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isAction ? Color.ink : .duckYellow)
                        .offset(x: isAction ? -4 * scale : 8)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottom) {
                if active {
                    Text("\(stored.wrappedValue.count)/\(limit)")
                        .font(TypeStyle.label(10)).foregroundStyle(.gray).offset(y: 16)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color(uiColor: isAction ? BreakScreen.actionInk : BreakScreen.titleInk))
            .multilineTextAlignment(.center)
            .background {
                ReminderKeyboardAnchor(active: active, keyboardTop: keyboardTop)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if miniature { focus.wrappedValue = part }
                else if isAction { proceed() }
            }
            .accessibilityElement(children: active ? .contain : .ignore)
            .accessibilityLabel(display)
            .accessibilityAddTraits(active ? [] : .isButton)
            .accessibilityIdentifier(miniature ? (isAction ? "settings.editAction" : "settings.editMessage") : (isAction ? "preview.proceed" : "preview.message"))
            .accessibilityAction {
                if miniature { focus.wrappedValue = part }
                else if isAction { proceed() }
            }
    }

}

// A text field inside a positioned miniature has no useful automatic scroll target.
// Keep its entire capsule visible rather than just its internal insertion point.
private struct ReminderKeyboardAnchor: UIViewRepresentable {
    let active: Bool
    let keyboardTop: CGFloat?
    final class Coordinator { var pending: DispatchWorkItem? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.pending?.cancel()
        guard active, let keyboardTop else { return }
        let work = DispatchWorkItem { [weak view] in
            guard let view, let window = view.window else { return }
            var ancestor = view.superview
            while let parent = ancestor, !(parent is UIScrollView) { ancestor = parent.superview }
            guard let scroll = ancestor as? UIScrollView else { return }
            let bottom = view.convert(view.bounds, to: window).maxY
            let overlap = bottom + 24 - keyboardTop
            guard overlap > 0 else { return }
            let maximum = max(-scroll.adjustedContentInset.top,
                              scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let y = min(maximum, scroll.contentOffset.y + overlap)
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: false)
        }
        context.coordinator.pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) { coordinator.pending?.cancel() }
}

private struct ReminderPreview: View {
    let voice: Voice
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: ReminderPart?
    @State private var revealed = false
    var body: some View {
        if revealed {
            DuckComicReveal(voice: voice, edition: 2) { dismiss() }
        } else {
            ReminderFace(voice: voice, miniature: false, message: .constant(SharedStore.reminderTitle(voice)),
                         action: .constant(SharedStore.actionTitle(voice)), focus: $focus) { revealed = true }
                .ignoresSafeArea().preferredColorScheme(.dark)
        }
    }
}

struct DuckComicReveal: View {
    @State private var breakImage: String?

    let voice: Voice
    let edition: Int
    let dismiss: () -> Void
    var body: some View {
        let title = [voice("OKAY.\nINTERMISSION.", "行啦。\n中场休息。"), voice("ONE MORE,\nHUH?", "又是\n最后一条？"), BreakDuckCopy.title(for: breakImage ?? "DuckLibrary07", voice: voice)][(0...2).contains(edition) ? edition : 2]
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 12) {
                HStack { Spacer(); Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
                }.accessibilityLabel(voice("Close", "关闭")) }
                Spacer(minLength: 0)
                HeroTitle(text: title, size: min(72, geo.size.width * 0.175))
                    .rotationEffect(.degrees(-2))
                ZStack {
                    Color.duckYellow
                    if edition == 0 {
                        Image("ShieldPanel").resizable().scaledToFill()
                    } else {
                        Image(edition == 1 ? "DuckLibrary04" : (breakImage ?? "DuckLibrary07")).resizable().scaledToFit()
                    }
                }.frame(width: geo.size.width - 40, height: min(geo.size.width - 40, geo.size.height * 0.46)).clipped()
                Text([voice("Even the algorithm needs a minute to miss you.", "让算法想你一会儿。"), voice("The feed can hold that thought.", "下一条，可以晚点再看。"), BreakDuckCopy.note(for: breakImage ?? "DuckLibrary07", voice: voice)][(0...2).contains(edition) ? edition : 2])
                    .font(TypeStyle.note(19)).padding(.top, 6)
                Spacer(minLength: 0)
            }.padding(.horizontal, 20).foregroundStyle(edition == 0 ? Color.paper : Color.ink)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background { Paper(dark: edition == 0) }
            .onAppear {
                guard edition != 0 && edition != 1, breakImage == nil else { return }
                breakImage = BreakDuckRotation.next()
            }
            .contentShape(Rectangle()).onTapGesture(perform: dismiss)
            .accessibilityAction(.escape, dismiss).preferredColorScheme(edition == 0 ? .dark : .light)
    }
}
