import SwiftUI

/// 最初の 10 秒：3 ページ。最後のページで不安を消す一文
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [(kicker: String, title: String, body: String)] = [
        ("Step 1", "選ぶと、段取りが出る", "作りたい品を何品か選ぶと、手・コンロ・レンジの空きから、まとめて作る順番を出します。煮ているあいだに、次の品を切る。"),
        ("Step 2", "作った容器は、冷蔵庫の棚へ", "容器にはマスキングテープのラベル。作った日と「あと何日」が見えて、食べきりたい順に並びます。"),
        ("Step 3", "食べきるほど、記録がたまる", "1 食たべたら記録。食べきり率と、捨てずに続いた日数がカレンダーに残ります。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer(minLength: 20)
                        illustration(index)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                        Text(pages[index].kicker.uppercased()).smallLabel()
                        Text(pages[index].title).font(Typo.serif(.title)).kerning(-0.5).foregroundStyle(Palette.ink)
                        Text(pages[index].body).font(Typo.body).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
                        if index == pages.count - 1 {
                            Text("記録はこの iPhone の中だけ。登録も通信もありません。")
                                .font(Typo.small).foregroundStyle(Palette.mintDeep)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 560)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule().fill(index == page ? Palette.mintDeep : Palette.line).frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: page)
            .accessibilityHidden(true)
            .padding(.bottom, 18)

            Button(page < pages.count - 1 ? "次へ" : "はじめる") {
                if page < pages.count - 1 {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { page += 1 }
                } else {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { model.onboardingDone = true }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 480)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: page) { _, _ in model.hapticsOn ? .selection : nil }
    }

    @ViewBuilder
    private func illustration(_ index: Int) -> some View {
        switch index {
        case 0:
            // 方眼のメモに段取りの帯
            ZStack(alignment: .topLeading) {
                GridPaper(spacing: 14)
                VStack(alignment: .leading, spacing: 10) {
                    bar(x: 0, w: 70, hands: true, label: "① 切る")
                    bar(x: 70, w: 120, hands: false, label: "① 煮る")
                    bar(x: 70, w: 60, hands: true, label: "② 切る")
                    bar(x: 130, w: 50, hands: true, label: "② 炒める")
                    bar(x: 180, w: 80, hands: false, label: "③ 漬ける")
                }
                .padding(18)
            }
            .background(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).fill(Palette.paper))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
        case 1:
            let samples = ["nikujaga", "kinpira", "kyuri-asazuke"].compactMap(RecipeBook.recipe)
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { i, r in
                        ContainerView(item: FridgeItem(recipeID: r.id, name: r.name, madeOn: Date(), keepsDays: r.keepsDays,
                                                       portions: r.portions, left: r.portions - i),
                                      freshness: [Freshness.soon, .fresh(3), .today][i])
                    }
                }
                .padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 10)
                ShelfLine()
            }
            .background(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
        default:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 18) {
                    BigNumber(value: "92", unit: "%", caption: "食べきり率")
                    BigNumber(value: "18", unit: "日", caption: "捨てずに")
                }
                HeatmapView(cells: Self.sampleCells)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
    }

    private func bar(x: CGFloat, w: CGFloat, hands: Bool, label: String) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(hands ? Palette.mint : Palette.mintSoft)
            .overlay(alignment: .leading) {
                Text(label).font(.system(size: 10, design: .serif)).foregroundStyle(Palette.ink).padding(.leading, 6)
            }
            .frame(width: w, height: 22)
            .offset(x: x)
    }

    /// 見本のカレンダー（固定の並び）
    static let sampleCells: [HeatCell] = (0..<56).map { i in
        let eaten = [2, 0, 3, 1, 4, 2, 1, 0, 3, 2, 5, 1, 2, 0][i % 14]
        return HeatCell(date: Date(timeIntervalSince1970: Double(i) * 86_400), eaten: eaten, discarded: i == 23 ? 1 : 0, isFuture: false)
    }
}
