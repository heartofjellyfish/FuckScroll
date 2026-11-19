import SwiftUI

extension Color {
    static let paper = Color(red: 253/255, green: 246/255, blue: 230/255)
    static let ink = Color(red: 0.095, green: 0.094, blue: 0.083)
    static let mutedInk = Color(red: 0.40, green: 0.39, blue: 0.36)
    static let duckYellow = Color(red: 254/255, green: 211/255, blue: 54/255)
}

enum TypeStyle {
    static func headline(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Heavy", size: size, relativeTo: .largeTitle) }
    static func note(_ size: CGFloat = 19) -> Font { .custom("Noteworthy-Bold", size: size, relativeTo: .body) }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

struct HeroTitle: View {
    let text: String
    var size: CGFloat = 64
    var body: some View {
        VStack(alignment: .leading, spacing: -20) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(line).font(TypeStyle.headline(size)).lineLimit(1)
                    .minimumScaleFactor(0.5).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAddTraits(.isHeader)
    }
}

struct Paper: View {
    var dark = false
    var body: some View {
        (dark ? Color.ink : Color.paper)
            .overlay {
                Canvas { context, size in
                    // Deterministic sparse paper grain; no animated noise or external texture.
                    for index in 0..<1800 {
                        let x = CGFloat((index * 7919) % 10007) / 10007 * size.width
                        let y = CGFloat((index * 3571) % 10009) / 10009 * size.height
                        let width = CGFloat(index % 3 + 1) * 0.35
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: width)), with: .color((dark ? Color.white : Color.black).opacity(0.022)))
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }.ignoresSafeArea()
    }
}

struct InkButton: View {
    let title: String
    var light = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title).font(TypeStyle.headline(23))
                Spacer()
            }
            .padding(.horizontal, 23).padding(.vertical, 16).frame(minHeight: 58)
            .foregroundStyle(light ? Color.ink : Color.paper)
            .background(light ? Color.paper : Color.ink, in: RoundedRectangle(cornerRadius: 10))
            .opacity(disabled ? 0.4 : 1)
        }.buttonStyle(PressStyle()).disabled(disabled)
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(TypeStyle.label()).tracking(2).foregroundStyle(Color.mutedInk)
    }
}

struct Duck: View {
    var mood = 0
    var walking = false
    var body: some View {
        Image(walking ? "DuckWalk" : mood >= 2 ? "DuckRage" : "DuckChill")
            .resizable().scaledToFit()
            .accessibilityLabel(mood >= 2 ? "A duck having an existential meltdown" : "A deeply unimpressed duck")
    }
}

struct CloseButton: View {
    @EnvironmentObject private var model: AppModel
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 24, weight: .black))
                .frame(width: 44, height: 44)
        }.accessibilityLabel(model.voice("Close","关闭")).foregroundStyle(Color.ink)
    }
}

struct Underline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY + 2))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 1), control: CGPoint(x: rect.midX * 0.8, y: -2))
        return path
    }
}

/// The controls stay quiet; the illustration carries the interruption.
struct ComicPanel: View {
    var mood = 0
    var done = false
    var caption: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var loud: Bool { mood >= 2 && !done }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if loud {
                    Canvas { context, size in
                        for index in 0..<24 {
                            let angle = Double(index) * .pi / 12
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            var line = Path()
                            line.move(to: CGPoint(x: center.x + cos(angle) * size.width * 0.38, y: center.y + sin(angle) * size.height * 0.38))
                            line.addLine(to: CGPoint(x: center.x + cos(angle) * size.width * 0.65, y: center.y + sin(angle) * size.height * 0.65))
                            context.stroke(line, with: .color(.ink), lineWidth: index.isMultiple(of: 3) ? 3 : 1)
                        }
                    }.clipShape(ComicFrame()).padding(.vertical, 23).padding(.horizontal, 9)
                }
                Image(done ? "ComicDone" : loud ? "ComicRage" : "ComicChill")
                    .resizable().scaledToFit()
                    .frame(width: geometry.size.width + (loud ? 14 : 0), height: geometry.size.height)
                    .rotationEffect(.degrees(done ? -7 : loud ? 4 : 0))
                if let caption, !dynamicTypeSize.isAccessibilitySize {
                    VStack {
                        HStack {
                            if !done { Spacer() }
                            Text(caption).font(TypeStyle.note(19)).lineSpacing(1)
                                .foregroundStyle(Color.ink).padding(.horizontal, 13).padding(.vertical, 7)
                                .background(Color.duckYellow)
                                .overlay(Rectangle().stroke(Color.ink, lineWidth: 1.5))
                                .rotationEffect(.degrees(5))
                            if done { Spacer() }
                        }
                        Spacer()
                    }.padding(.top, 2)
                }
            }
        }.accessibilityHidden(true)
    }
}

struct ComicFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.minY + 11))
        path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct InkRule: View {
    var variant = 0
    var weight: CGFloat = 2.1
    var body: some View {
        Canvas { context, size in
            let sign: CGFloat = variant.isMultiple(of: 2) ? 1 : -1
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 2))
            path.addQuadCurve(to: CGPoint(x: size.width, y: 2 + sign * 0.45),
                control: CGPoint(x: size.width * (0.34 + CGFloat(variant % 4) * 0.09), y: 2 - sign * 0.8))
            context.stroke(path, with: .color(.ink), style: StrokeStyle(lineWidth: weight, lineCap: .round))
        }.frame(height: 5).accessibilityHidden(true)
    }
}
struct InkChoice: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(TypeStyle.headline(19)).padding(.horizontal, 12).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.paper : Color.ink)
                .background(selected ? Color.ink : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.ink, lineWidth: 2))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}


/// Advance only when a new break illustration is presented, never during body updates.
enum BreakDuckRotation {
    static func next() -> String {
        let defaults = UserDefaults.standard
        let key = "breakDuckRotation"
        let previous = defaults.integer(forKey: key)
        let index = max(0, previous) % 6
        defaults.set(index + 1, forKey: key)
        return String(format: "DuckLibrary%02d", 7 + index)
    }
}


/// Artwork and its words are selected together, including in reminder previews.
enum BreakDuckCopy {
    static func title(for image: String, voice: Voice) -> String {
        switch image {
        case "DuckLibrary08": return voice("BUSY\nDOING NOTHING.", "忙着\n什么都不干。")
        case "DuckLibrary09": return voice("SOMETHING\nNEEDS WATER.", "有位朋友\n需要水。")
        case "DuckLibrary10": return voice("YOUR LEGS\nMISS YOU.", "你的腿\n想你了。")
        case "DuckLibrary11": return voice("LET IT\nBREW.", "泡一会儿。\n别刷了。")
        case "DuckLibrary12": return voice("PHONE'S\nBEDTIME.", "手机该\n睡觉了。")
        default: return voice("TAKE THE\nSCENIC ROUTE.", "慢慢走。\n不赶时间。")
        }
    }
    static func note(for image: String, voice: Voice) -> String {
        switch image {
        case "DuckLibrary08": return voice("Doing nothing counts.", "发呆也算休息。")
        case "DuckLibrary09": return voice("You could use a drink too.", "你也喝口水吧。")
        case "DuckLibrary10": return voice("They do more than hold your phone.", "腿可不只是手机支架。")
        case "DuckLibrary11": return voice("Steep. Don't scroll.", "泡茶，别泡在屏幕里。")
        case "DuckLibrary12": return voice("It's had enough of you too.", "它也想歇会儿，真的。")
        default: return voice("Still faster than scrolling.", "总比原地刷屏走得远。")
        }
    }
}

/// Broad, three-lobed webbing: a duck's signature rather than a mammal paw.
struct DuckFootMark: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        p.move(to: pt(0.50, 0.03))
        p.addCurve(to: pt(0.67, 0.29), control1: pt(0.65, 0.01), control2: pt(0.60, 0.26))
        p.addCurve(to: pt(0.91, 0.24), control1: pt(0.76, 0.35), control2: pt(0.81, 0.17))
        p.addCurve(to: pt(0.89, 0.58), control1: pt(1.04, 0.27), control2: pt(0.97, 0.46))
        p.addCurve(to: pt(0.59, 0.83), control1: pt(0.81, 0.70), control2: pt(0.67, 0.78))
        p.addCurve(to: pt(0.52, 0.99), control1: pt(0.58, 0.94), control2: pt(0.61, 0.98))
        p.addCurve(to: pt(0.41, 0.84), control1: pt(0.42, 1.02), control2: pt(0.42, 0.94))
        p.addCurve(to: pt(0.09, 0.59), control1: pt(0.27, 0.79), control2: pt(0.17, 0.71))
        p.addCurve(to: pt(0.10, 0.25), control1: pt(-0.02, 0.44), control2: pt(-0.02, 0.28))
        p.addCurve(to: pt(0.34, 0.29), control1: pt(0.21, 0.20), control2: pt(0.23, 0.35))
        p.addCurve(to: pt(0.50, 0.03), control1: pt(0.42, 0.25), control2: pt(0.35, 0.04))
        p.closeSubpath()
        return p
    }
}

struct DuckFootSignature: View {
    var body: some View {
        DuckFootMark().fill(Color.duckYellow)
            .overlay {
                GeometryReader { geometry in
                    Path { p in
                        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                            CGPoint(x: x * geometry.size.width, y: y * geometry.size.height)
                        }
                        // Three soft folds radiate from the sole into the webbing.
                        p.move(to: pt(0.43, 0.67))
                        p.addQuadCurve(to: pt(0.21, 0.43), control: pt(0.30, 0.55))
                        p.move(to: pt(0.51, 0.61))
                        p.addQuadCurve(to: pt(0.50, 0.28), control: pt(0.48, 0.44))
                        p.move(to: pt(0.60, 0.66))
                        p.addQuadCurve(to: pt(0.80, 0.43), control: pt(0.71, 0.56))
                        // A small heel crease, not a separate paw pad.
                        p.move(to: pt(0.43, 0.78))
                        p.addQuadCurve(to: pt(0.59, 0.78), control: pt(0.51, 0.82))
                    }.stroke(Color.ink, style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
                }
            }.accessibilityHidden(true)
    }
}
