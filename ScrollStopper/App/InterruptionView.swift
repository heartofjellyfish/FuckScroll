import SwiftUI

struct InterruptionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let preview: Bool
    let initialMood: Int
    @State private var mood = 0
    @State private var stage = 0
    @State private var chosen = 0
    @State private var goodbyeImage: String?
    private var dark: Bool { stage == 0 && mood >= 2 }
    private var foreground: Color { dark ? .paper : .ink }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(model.isRehearsal ? model.voice("SIMULATION · NO APPS BLOCKED", "模拟体验 · 未拦截任何 APP") : preview ? model.voice("PREVIEW", "预览") : "")
                            .font(TypeStyle.label(10)).tracking(1.3).opacity(0.65)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16)).frame(width: 44, height: 44)
                        }.accessibilityLabel(model.voice("Close", "关闭"))
                    }.padding(.top, 14)
                    if stage == 0 { interruption(height: geometry.size.height) }
                    else if stage == 1 { alternatives(height: geometry.size.height) }
                    else { goodbye(height: geometry.size.height) }
                }.padding(.horizontal, 30).frame(minHeight: geometry.size.height, alignment: .topLeading)
            }.scrollIndicators(.hidden)
        }.foregroundStyle(foreground).background { Paper(dark: dark) }
            .preferredColorScheme(dark ? .dark : .light)
            .onAppear {
                mood = initialMood
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--alternatives") { stage = 1 }
                if args.contains("--goodbye") { stage = 2 }
                #endif
            }
    }
    private func interruption(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroTitle(text: model.voice.title(mood: mood).uppercased(), size: height < 720 ? 56 : (mood >= 2 ? 65 : 73))
                .rotationEffect(.degrees(mood >= 2 ? -4 : -2))
                .padding(.top, height < 720 ? 18 : 30).accessibilityAddTraits(.isHeader)
            ComicPanel(mood: mood)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 140 : height < 720 ? 200 : min(310, height * 0.38))
                .padding(.horizontal, -12).padding(.top, 12)
            Spacer(minLength: 12)
            Text(model.voice.remark(mood: mood, variant: preview ? 0 : (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0))).font(.body.weight(.medium)).lineSpacing(4)
                .padding(.bottom, 22)
            if !preview, model.resting, let until = model.session.cooldownUntil {
                HStack {
                    Text(model.voice("Break remaining", "还要歇"))
                    Spacer()
                    Text(until, style: .timer).monospacedDigit()
                }.font(TypeStyle.label(12)).padding(.bottom, 18).accessibilityIdentifier("interruption.remaining")
            } else if !preview {
                Text(model.voice("Break’s over.", "歇够了。"))
                    .font(TypeStyle.note(15)).padding(.bottom, 14).accessibilityIdentifier("interruption.expired")
            }
            InkButton(title: model.voice("Phone down.", "放下了。"), light: dark) { dismiss() }
                .accessibilityIdentifier("interruption.putDown")
            Button { move(to: 1) } label: {
                Text(model.voice("Now what?", "干点啥？"))
                    .font(.subheadline.weight(.medium)).underline().frame(maxWidth: .infinity).padding(.vertical, 14)
            }.accessibilityIdentifier("interruption.alternatives")
            if preview {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { mood = (mood + 1) % 3 }
                    if !reduceMotion { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                } label: {
                    Text(model.voice(mood < 2 ? "Still scrolling?" : "Chill.", mood < 2 ? "还刷呢？" : "冷静。"))
                        .font(TypeStyle.note(15)).frame(maxWidth: .infinity).padding(.vertical, 10)
                }.accessibilityIdentifier("interruption.escalate")
            } else {
                Text(model.resting ? model.voice("The break stays on.", "关掉也得歇。") : "")
                    .font(TypeStyle.note(15)).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
        }
    }
    private func alternatives(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroTitle(text: model.voice("TRY\nREAL LIFE.", "试试\n现实生活。"), size: height < 720 ? 50 : 60).padding(.top, height < 720 ? 20 : 30)
            Color.clear.frame(height: 24)
            ForEach(0..<3) { index in
                Button { chosen = index } label: {
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: chosen == index ? "checkmark.square.fill" : "square").font(.system(size: 23, weight: .light)).padding(.top, 2)
                        Text(optionTitle(index)).font(.system(size: 20, weight: .semibold))
                        Spacer(minLength: 0)
                    }.padding(.vertical, height < 720 ? 11 : 16)
                }.accessibilityAddTraits(chosen == index ? .isSelected : [])
                    .accessibilityIdentifier("alternatives.option.\(index)")
                Rectangle().fill(Color.ink.opacity(0.14)).frame(height: 1)
            }
            if height >= 720 && !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Spacer()
                    Duck().frame(width: 85, height: 125)
                }.padding(.top, 20)
            }
            Spacer(minLength: 18)
            InkButton(title: model.voice("Let’s go.", "走了。")) { move(to: 2) }
                .accessibilityIdentifier("alternatives.done").padding(.bottom, 20)
        }
    }
    private func goodbye(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroTitle(text: BreakDuckCopy.title(for: goodbyeImage ?? "DuckLibrary07", voice: model.voice), size: height < 720 ? 54 : 66).rotationEffect(.degrees(-2)).padding(.top, height < 720 ? 20 : 30)
            Text(goodbyeNote)
                .font(TypeStyle.note(21)).padding(.top, 13)
            Image(goodbyeImage ?? "DuckLibrary07").resizable().scaledToFit()
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 110 : height < 720 ? 150 : min(300, height * 0.36))
                .padding(.horizontal, -10).padding(.top, 20)
            Spacer(minLength: 20)
            InkButton(title: model.voice("Bye, duck.", "走了，鸭。")) { dismiss() }
                .accessibilityIdentifier("goodbye.close")
                .padding(.bottom, 20)
        }
    }
    private func optionTitle(_ index: Int) -> String {
        switch index {
        case 0: return model.voice("Stand up.", "站起来。")
        case 1: return model.voice("Drink water.", "喝点水。")
        default: return model.voice("Look outside.", "看看窗外。")
        }
    }
    private var goodbyeNote: String {
        BreakDuckCopy.note(for: goodbyeImage ?? "DuckLibrary07", voice: model.voice)
    }
    private func move(to stage: Int) {
        if stage == 2 && goodbyeImage == nil { goodbyeImage = BreakDuckRotation.next() }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { self.stage = stage }
    }
}
