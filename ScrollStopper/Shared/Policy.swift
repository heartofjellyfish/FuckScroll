import Foundation

/// Pure decision rules, shared by the app and all extensions.
enum ScrollPolicy {
    static let minuteOptions = [1, 2, 5, 10, 15, 20, 30, 45, 60]
    static func validLimit(_ value: Int) -> Int { (1...120).contains(value) ? value : 20 }
    // A two-hour quiet gap ends the streak; old breaks cannot return after a new one.
    // Presentation only: never changes a usage allowance or an active break.
    static func recentBreakCount(_ dates: [Date], at now: Date, calendar: Calendar = .current) -> Int {
        let today = dates.filter { $0 <= now && calendar.isDate($0, inSameDayAs: now) }.sorted(by: >)
        var previous = now
        var count = 0
        for date in today {
            guard previous.timeIntervalSince(date) < 2 * 60 * 60 else { break }
            count += 1
            previous = date
        }
        return count
    }
    static func homeVersions(offDuty: Bool, resting: Bool, breakCount: Int) -> [Int] {
        if offDuty { return [19, 20] }
        if resting { return [16, 17] }
        if breakCount >= 5 { return [14, 15] }
        if breakCount >= 3 { return [11, 12, 13] }
        return Array(1...10) + [18]
    }
    static func homeDuck(breakCount: Int, variant: Int) -> String {
        let number = breakCount >= 7 ? 6 : breakCount >= 5 ? 5 : breakCount >= 3 ? 4 : (variant % 2 == 0 ? 1 : 2)
        return String(format: "DuckLibrary%02d", number)
    }
    static func mood(for interruptions: Int) -> Int { min(max(interruptions, 0), 2) }
}

enum AppSelectionIssue: Equatable {
    case tooManyApps
    case unsupportedItems

    init?(appCount: Int, maximumApps: Int, hasUnsupportedItems: Bool) {
        if appCount > maximumApps {
            self = .tooManyApps
        } else if hasUnsupportedItems {
            self = .unsupportedItems
        } else {
            return nil
        }
    }

    func message(_ voice: Voice) -> String {
        switch self {
        case .tooManyApps:
            return voice("Choose up to 9 apps.", "最多选择 9 个 App。")
        case .unsupportedItems:
            return voice("Whole categories and websites aren’t supported. Open a category and pick individual apps.", "暂不支持整类 App 或网站。请展开分类，逐个选择 App。")
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case english, chinese, traditional = "zh-Hant", spanish = "es", french = "fr", german = "de", italian = "it", japanese = "ja", korean = "ko", portuguese = "pt-BR"
    var code: String { self == .english ? "en" : self == .chinese ? "zh-Hans" : rawValue }
    var title: String {
        switch self {
        case .english: "English"; case .chinese: "简体中文"; case .traditional: "繁體中文"
        case .spanish: "Español"; case .french: "Français"; case .german: "Deutsch"
        case .italian: "Italiano"; case .japanese: "日本語"; case .korean: "한국어"; case .portuguese: "Português (Brasil)"
        }
    }
    static func preferred(_ languages: [String] = Locale.preferredLanguages) -> Self {
        for tag in languages {
            let lang = Locale.Language(identifier: tag)
            if lang.languageCode?.identifier == "zh" { return lang.script?.identifier == "Hant" ? .traditional : .chinese }
            if lang.languageCode?.identifier == "pt" { return .portuguese }
            if let match = allCases.first(where: { $0.code == lang.languageCode?.identifier }) { return match }
        }
        return .english
    }
}

struct Voice {
    let language: AppLanguage
    func callAsFunction(_ english: String, _ chinese: String) -> String {
        if language == .chinese { return chinese }
        guard language != .english, let url = Bundle.main.url(forResource: language.code, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return english }
        return bundle.localizedString(forKey: english, value: english, table: "Duck")
    }
    func minutes(_ n: Int, _ english: String = "%d min", _ chinese: String = "%d 分钟") -> String {
        String(format: self(english, chinese), locale: Locale(identifier: language.code), n)
    }
    func ruleSummary(usage: Int, rest: Int) -> String {
        let format = self("At %1$d min total, this app locks for %2$d min. Stay away for %2$d min to start fresh.",
                          "累计用满 %1$d 分钟，锁 %2$d 分钟。提前离开满 %2$d 分钟，用时清零。")
        return String(format: format, locale: Locale(identifier: language.code), usage, rest)
    }
    func title(mood: Int) -> String {
        switch ScrollPolicy.mood(for: mood) {
        case 0: return self("Still\nscrolling?", "还刷呢？")
        case 1: return self("Still?\nSeriously?", "不是。\n还刷？")
        default: return self("FOR FUCK’S\nSAKE.", "我靠。\n还！在！刷！")
        }
    }
    func remark(mood: Int, variant: Int = 0) -> String {
        let bank: [(String, String)]
        switch ScrollPolicy.mood(for: mood) {
        case 0: bank = [
            ("Long minute, huh?", "这一眼，够久的。"),
            ("Your evening has an ending.", "你的晚上可不是无限的。"),
            ("What did you come for?", "你打开它要干吗来着？"),
            ("Enough strangers. You good?", "别人看够了。你呢？"),
            ("Nothing new. Breathe.", "没啥新鲜的。喘口气。")
        ]
        case 1: bank = [
            ("Expecting a plot twist?", "还等反转呢？"),
            ("The algorithm thanks you.", "算法谢谢你。"),
            ("Even the ads recognize you.", "广告都认识你了。"),
            ("‘One more.’ Sure.", "『最后一个。』呵。"),
            ("Even I need fresh air.", "连我都想透口气。")
        ]
        default: bank = [
            ("Let the algorithm miss you.", "让算法想你一会儿。"),
            ("Same shit. New username.", "同样的破事。换了个号。"),
            ("The feed won’t tuck you in.", "信息流不管哄睡。"),
            ("PUT. IT. DOWN.", "放！下！"),
            ("Three feathers left. Please.", "剩三根毛了。求你。")
        ]
        }
        let entry = bank[((variant % bank.count) + bank.count) % bank.count]
        return self(entry.0, entry.1)
    }
}
