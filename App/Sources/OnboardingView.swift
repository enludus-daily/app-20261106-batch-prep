import SwiftUI

/// 最初の 10 秒：3 ページ（ルートを出す → 走る → 食べきって完食）。どの見本にも文字のラベルを付ける。
/// ページ送りは自前（TabView の page は使わない）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [(kicker: String, title: String, body: String)] = [
        ("Step 1", "作り置きを、ルートにする", "作りたい品を選ぶと、手・コンロ・レンジの空きから、まとめて作る順番（ルート）を出します。煮ているあいだに、次の品を切る。"),
        ("Step 2", "ルートを走る", "工程が終わるたびに「できた」。目安と自己ベストとの差が、その場で出ます。"),
        ("Step 3", "食べきって、完食", "ゴールすると、タイム・ランク・1 品ずつより何倍速か。作った品を期限までに食べきると、そのランは「完食」。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("スキップ") { finish() }
                        .font(Typo.small).foregroundStyle(Palette.sub).frame(minHeight: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            ZStack {
                ForEach(pages.indices, id: \.self) { index in
                    if index == page {
                        pageView(index)
                            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -40, page < pages.count - 1 { go(page + 1) }
                if value.translation.width > 40, page > 0 { go(page - 1) }
            })

            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule().fill(index == page ? Palette.skyDeep : Palette.line).frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: page)
            .accessibilityHidden(true)
            .padding(.bottom, 16)

            Button(page < pages.count - 1 ? "次へ" : "はじめる") {
                if page < pages.count - 1 { go(page + 1) } else { finish() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: page) { _, _ in model.hapticsOn ? .selection : nil }
    }

    private func go(_ next: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { page = next }
    }

    private func finish() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { model.onboardingDone = true }
    }

    private func pageView(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            illustration(index)
                .frame(maxWidth: .infinity)
            Text(pages[index].kicker.uppercased()).smallLabel()
            Text(pages[index].title).font(Typo.serif(.title)).kerning(-0.5).foregroundStyle(Palette.ink)
            Text(pages[index].body).font(Typo.body).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            if index == pages.count - 1 {
                Text("記録はこの iPhone の中だけ。登録も通信もありません。")
                    .font(Typo.small).foregroundStyle(Palette.skyDeep)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: 560)
    }

    private static let sampleIDs = ["nikujaga", "kinpira", "kyuri-asazuke"]

    @ViewBuilder
    private func illustration(_ index: Int) -> some View {
        let recipes = Self.sampleIDs.compactMap(RecipeBook.recipe)
        switch index {
        case 0:
            let plan = Scheduler.plan(recipes)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { i, recipe in
                        VStack(spacing: 2) {
                            DishIcon(recipe: recipe, size: 34)
                            Text("\(i + 1) \(recipe.name)").font(.system(size: 10)).foregroundStyle(Palette.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                TimelineChart(plan: plan, order: Self.sampleIDs, rowHeight: 22)
                HStack(spacing: 12) {
                    Text("目安 \(plan.totalMinutes) 分").font(.system(.footnote, design: .serif)).foregroundStyle(Palette.ink)
                    Text("1 品ずつだと \(plan.sequentialMinutes) 分").font(.system(.footnote, design: .serif)).foregroundStyle(Palette.sub)
                }
            }
            .panel(padding: 14)
        case 1:
            VStack(spacing: 12) {
                Text("18:42").font(Typo.number(64)).kerning(-3).monospacedDigit().foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    sample(title: "目安", value: "−0:50", color: Palette.skyDeep)
                    sample(title: "自己ベスト", value: "+0:12", color: Palette.peachInk)
                }
                HStack(spacing: 10) {
                    if let r = recipes.first { DishIcon(recipe: r, size: 38) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("いま、手を動かす").font(Typo.label).foregroundStyle(Palette.peachInk)
                        Text("肉と野菜を炒める").font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                    Text("できた").font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Palette.skyDeep))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).stroke(Palette.peach.opacity(0.7), lineWidth: 1.2))
            }
            .panel(padding: 16)
        default:
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("42:18").font(Typo.number(54)).kerning(-2.5).monospacedDigit().foregroundStyle(Palette.ink)
                    Spacer()
                    RankBadge(rank: .s, size: 54)
                }
                HStack(spacing: 8) {
                    PBTag(text: "自己ベスト更新")
                    Text("2.4 倍速・並行 61%").font(.system(.footnote, design: .serif)).foregroundStyle(Palette.sub)
                }
                HStack(spacing: 10) {
                    ForEach(recipes) { recipe in DishIcon(recipe: recipe, size: 36) }
                    Spacer()
                    Text("完食").font(.system(.footnote, weight: .semibold)).foregroundStyle(Palette.skyDeep)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Palette.skySoft))
                }
            }
            .panel(padding: 16)
        }
    }

    private func sample(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(title).font(.system(size: 11)).foregroundStyle(Palette.sub)
            Text(value).font(.system(size: 14, design: .serif)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Palette.ground))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 0.8))
    }
}
