import SwiftUI
import FamilyControls
import ManagedSettings

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastSelection = Date.distantPast
    @State private var homeVersion = 1
    @State private var selectedHome = false
    private var canResume: Bool { model.dutyStatus == .off || model.dutyStatus == .starting }
    private var headline: String { model.voice(HomeDuckContent.entries[homeVersion - 1].0, HomeDuckContent.entries[homeVersion - 1].1) }
    private func selectHome() {
        #if DEBUG
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--qa-home-version"),
           ProcessInfo.processInfo.arguments.indices.contains(i + 1),
           let n = Int(ProcessInfo.processInfo.arguments[i + 1]), (1...20).contains(n) {
            homeVersion = n; selectedHome = true; return
        }
        #endif
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "home20.introduced") {
            homeVersion = 1
            defaults.set(true, forKey: "home20.introduced")
        } else {
            let dates = model.states.values.values.flatMap { $0.dailyBreakDates ?? [] }
            let count = ScrollPolicy.recentBreakCount(dates, at: Date())
            let pool = ScrollPolicy.homeVersions(offDuty: canResume, resting: model.resting, breakCount: count)
            let seen = defaults.array(forKey: "home20.seen") as? [Int] ?? []
            let unseen = pool.filter { !seen.contains($0) }
            let previous = defaults.integer(forKey: "home20.last")
            let candidates = unseen.isEmpty ? pool.filter { $0 != previous } : unseen
            homeVersion = candidates.randomElement() ?? pool[0]
            defaults.set(unseen.isEmpty ? [homeVersion] : seen + [homeVersion], forKey: "home20.seen")
        }
        defaults.set(homeVersion, forKey: "home20.last")
        selectedHome = true
        lastSelection = Date()
    }
    var body: some View {
        GeometryReader { geometry in
            Group {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if model.dutyStatus != .noRules {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(model.dutyStatus == .on ? Color(red: 0.24, green: 0.60, blue: 0.36) : Color.mutedInk)
                                    .frame(width: 7, height: 7)
                                    .accessibilityHidden(true)
                                Text(model.dutyLabel).font(TypeStyle.label(10))
                            }
                            if canResume || (model.dutyStatus == .check && model.authorized) {
                                Button {
                                    if model.dutyStatus == .check { model.retryDuty() }
                                    else { model.setDuty(true) }
                                } label: {
                                    Text(model.dutyStatus == .check ? model.voice("Retry", "重试") : model.voice("Wake up", "叫醒它"))
                                        .font(TypeStyle.headline(16))
                                        .padding(.horizontal, 10).padding(.vertical, 3)
                                        .background(Color.duckYellow)
                                        .overlay(Rectangle().strokeBorder(Color.ink, lineWidth: 1.3))
                                        .rotationEffect(.degrees(-2)).frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).disabled(model.saving)
                                .accessibilityIdentifier("home.wake")
                            }
                        }
                        Spacer()
                        Button { model.showSettings = true } label: {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 23, weight: .black)).frame(width: 44, height: 44)
                        }.accessibilityLabel(model.voice("Settings", "设置")).accessibilityIdentifier("home.settings")
                    }.padding(.top, 8)
                    HeroTitle(text: headline, size: min(58, geometry.size.height * 0.076))
                        .padding(.top, 12).accessibilityAddTraits(.isHeader)
                    if model.dutyStatus == .on && !model.resting {
                        Text(model.voice(HomeDuckContent.entries[homeVersion - 1].2, HomeDuckContent.entries[homeVersion - 1].3))
                            .font(TypeStyle.note()).foregroundStyle(Color.ink)
                            .padding(.top, 5)
                    }
                    Image(String(format: "HomeDuck%02d", homeVersion))
                        .resizable().scaledToFit().accessibilityHidden(true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, -10).padding(.top, 12)
                    Color.clear.frame(height: 12)
                    if model.firstDutyThisVisit && model.dutyStatus == .on && !model.resting {
                        Text(model.voice("Close the duck. Limits still work.", "关掉鸭子，限时照常。"))
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 18, relativeTo: .body))
                            .frame(maxWidth: .infinity).padding(.bottom, 8)
                    }
                    let entries = breakEntries
                    if !entries.isEmpty { BreakTicket(entries: entries) }
                    if !model.rules.isEmpty || !entries.isEmpty {
                        Button { model.edit() } label: {
                            HStack(spacing: 6) {
                                if entries.isEmpty {
                                    ForEach(Array(model.rules.prefix(4))) { rule in
                                        Label(rule.token).labelStyle(.iconOnly).fixedSize()
                                    }
                                    if model.rules.count > 4 { Text("+\(model.rules.count - 4)") }
                                    Spacer()
                                }
                                Text(model.voice("Your limits", "使用限度")).font(TypeStyle.headline(21))
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                            }.padding(.horizontal, 13).frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                                .overlay { if entries.isEmpty { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ink, lineWidth: 2) } }
                        }.padding(.top, 4).accessibilityIdentifier("home.rules")
                    }
                    if model.rules.isEmpty && entries.isEmpty {
                        Button { model.edit() } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                                Text(model.voice("Select apps", "选择 App")).font(TypeStyle.headline(21))
                            }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("home.connect")
                    } else if !model.authorized && !model.isRehearsal {
                        InkButton(title: model.voice("Allow Screen Time", "允许屏幕使用时间")) { model.edit() }
                            .padding(.top, 10).accessibilityIdentifier("home.connect")
                    }
                }.padding(.horizontal, 28).padding(.bottom, 22)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
        }.background { Paper() }.foregroundStyle(Color.ink)
            .onAppear { if !selectedHome { selectHome() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && selectedHome && Date().timeIntervalSince(lastSelection) > 120 { selectHome() }
            }
            .onChange(of: model.dutyStatus) { _, _ in if selectedHome { selectHome() } }
            .onChange(of: model.resting) { _, _ in if selectedHome { selectHome() } }
            .alert(model.voice("Couldn’t start.", "没启动成功。"), isPresented: Binding(
                get: { model.error != nil && !model.showSettings && !model.showSetup },
                set: { if !$0 { model.error = nil } }
            )) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
    }
    private var breakEntries: [BreakEntry] {
        #if DEBUG
        if model.isRehearsal, model.resting, let end = model.session.cooldownUntil {
            let count = min(9, max(1, UserDefaults.standard.integer(forKey: "rehearsalCount")))
            return (0..<count).map { index in
                let storeOffsets = [-380, -664, -220, -528, -345, -150, -404, -280, -600]
                let offset = ProcessInfo.processInfo.arguments.contains("--qa-store-market")
                    ? storeOffsets[index] : (count == 2 ? (index == 0 ? -380 : -664) : -7 * index)
                return BreakEntry(id: String(index), token: nil, end: end.addingTimeInterval(Double(offset)))
            }
        }
        #endif
        return model.rules.compactMap { rule in
            guard let end = model.states.values[rule.id]?.cooldownUntil, end > Date() else { return nil }
            return BreakEntry(id: rule.id, token: rule.token, end: end)
        }
    }
}

private struct BreakEntry: Identifiable {
    let id: String
    let token: ApplicationToken?
    let end: Date
}

private struct BreakTicket: View {
    let entries: [BreakEntry]
    var body: some View {
        let fullGrid = entries.count == 9
        let columns = fullGrid ? 3 : entries.count <= 5 ? entries.count : (entries.count + 1) / 2
        let ticketHeight: CGFloat = fullGrid ? 110 : 76
        let dense = entries.count > 5
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<(fullGrid ? 3 : dense ? 2 : 1), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(Array(entries.dropFirst(row * columns).prefix(columns))) { entry in
                            let single = entries.count == 1
                            let layout = single || dense ? AnyLayout(HStackLayout(spacing: single ? 7 : 2)) : AnyLayout(VStackLayout(spacing: 2))
                            layout {
                                icon(entry, size: dense ? 18 : single ? 26 : 22)
                                Text(entry.end, style: .timer)
                                    .font(.system(size: single ? 36 : dense ? 16 : entries.count < 4 ? 25 : 20, weight: .bold, design: .rounded))
                                    .fontWidth(dense ? .condensed : .standard).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: single || dense, vertical: false)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: (geo.size.width - 12) / CGFloat(columns), height: fullGrid ? 32 : dense ? 36 : 76)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("break.cell." + entry.id)
                        }
                    }
                }
            }.frame(width: geo.size.width, height: ticketHeight)
        }.frame(height: ticketHeight)
            .background(Color.duckYellow, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.ink, lineWidth: 1.5))
    }

    @ViewBuilder private func icon(_ entry: BreakEntry, size: CGFloat) -> some View {
        if let token = entry.token {
            Label(token).labelStyle(.iconOnly).fixedSize()
                .scaleEffect(size / 20).frame(width: size, height: size)
        } else {
            #if DEBUG && targetEnvironment(simulator)
            if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
               let image = UIImage(contentsOfFile: url.appendingPathComponent("qa-icon-" + entry.id + ".png").path) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else { Image(systemName: "app.fill").frame(width: size, height: size) }
            #endif
        }
    }
}

private enum HomeDuckContent {
    static let entries: [(String, String, String, String)] = [
        ("ALGORITHM\nVS.\nDUCK.", "算法\n对阵\n鸭子。", "They have billions. You have me.", "他们有钱。你有我。"),
        ("YOU SCROLL.\nI SIP.\nWE TALK.", "你刷。\n我喝。\n聊聊？", "My coffee’s getting cold.", "咖啡都快凉了。"),
        ("BREAKING\nNEWS:\nOUTSIDE EXISTS.", "最新\n消息：\n外面还在。", "Surprisingly good resolution.", "画质意外地好。"),
        ("SMALL DUCK.\nBIG\nRESPONSIBILITY.", "小鸭子。\n大\n责任。", "I asked for a pond.", "我只想要个池塘。"),
        ("YOUR FEED\nHAS NO\nENDING.", "你的动态\n没有\n大结局。", "Terrible storytelling.", "这编剧不太行。"),
        ("VERY\nQUALIFIED\nDUCK.", "相当\n专业的\n鸭子。", "References available. Mostly ducks.", "有推荐人。基本都是鸭子。"),
        ("JUST\nWINGING\nIT.", "边干\n边想\n办法。", "Professionally.", "专业地。"),
        ("NOTHING\nGETS\nPAST ME.", "什么\n都逃不过\n我的眼。", "Except most things. I’m a duck.", "除了大多数事。我是只鸭。"),
        ("YOUR TIME.\nMY\nBUSINESS.", "你的时间。\n我的\n差事。", "Weird little partnership.", "奇妙的搭档。"),
        ("THE FEED\nCAN\nWAIT.", "信息流\n可以\n等一等。", "It has literally no plans.", "它又没别的安排。"),
        ("“ONE MORE.”\nFAMOUS\nLAST WORDS.", "“最后一条。”\n经典\n台词。", "I admire the optimism.", "欣赏你的乐观。"),
        ("WE’VE\nBEEN\nHERE.", "这里\n咱们\n来过。", "Lovely place. Let’s leave.", "挺好的。走吧。"),
        ("BACK\nSO\nSOON?", "这么快\n又\n回来了？", "I haven’t even blinked.", "我还没眨眼呢。"),
        ("I KEPT\nTHE\nRECEIPTS.", "我留着\n你的\n账单。", "We don’t have to discuss them.", "可以不展开聊。"),
        ("QUITE\nTHE\nSCROLL.", "这屏\n刷得\n够长。", "Shall we call it a day?", "今天就到这儿？"),
        ("YOUR THUMB\nCALLED\nA MEETING.", "你的拇指\n要求\n开个会。", "It wants better hours.", "它想少加点班。"),
        ("THE PHONE\nWILL\nSURVIVE.", "手机\n不会\n有事的。", "Very brave little rectangle.", "勇敢的小方块。"),
        ("NEW ROUND.\nSAME DUCK.\nNO GRUDGES.", "新一轮。\n老鸭子。\n不记仇。", "We’re good.", "咱俩没事。"),
        ("OFF DUTY.\nSTILL\nADORABLE.", "下班了。\n依然\n可爱。", "Terrible security. Excellent company.", "看门不行。陪你挺好。"),
        ("TAKING\nMY OWN\nADVICE.", "我先\n听听\n自己的。", "Someone has to.", "总得有个听劝的。")
    ]
}
