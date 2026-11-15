import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroTitle(text: model.voice("YOU WERE\nJUST GOING\nTO CHECK.", "本来\n就看\n一眼。"), size: geometry.size.height < 720 ? 48 : 62)
                        .rotationEffect(.degrees(-2))
                        .padding(.top, geometry.size.height < 720 ? 20 : 34)
                        .accessibilityAddTraits(.isHeader)
                    ComicPanel()
                        .frame(height: geometry.size.height < 720 ? 190 : min(280, geometry.size.height * 0.34))
                        .padding(.horizontal, -10).padding(.top, 12)
                    Spacer(minLength: 12)
                    Text(model.voice("Scroll too long. Get cut off.", "刷太久，就拦住。"))
                        .font(.callout).foregroundStyle(Color.mutedInk).lineSpacing(4)
                        .padding(.bottom, 24)
                    InkButton(title: model.voice("Set my limit", "设个限度")) { model.showSetup = true }
                        .accessibilityIdentifier("welcome.setup")

                }
                .padding(.horizontal, 30)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }.scrollIndicators(.hidden)
        }.background { Paper() }.foregroundStyle(Color.ink)
    }
}
