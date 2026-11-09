import SwiftUI

/// ランの結果：大きなタイム・ランク・自己ベスト・手際の数字・スプリット。共有カード（数字と器だけ）
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: RunRecord
    @State private var shown = false

    private var recipes: [Recipe] { record.recipeIDs.compactMap(RecipeBook.recipe) }
    private var isPB: Bool { RunMath.isPersonalBest(record, in: model.runs) }
    private var previousBest: RunRecord? {
        RunMath.best(model.runs.filter { $0.date <= record.date }, courseKey: record.courseKey, excluding: record.id)
    }
    private var route: [RouteStep] {
        RunMath.route(Scheduler.plan(recipes, kitchen: KitchenSetup(burners: record.burners)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("FINISH").smallLabel()
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.sub).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                hero
                numbers
                dishes
                splits
                ShareLink(item: shareImage, preview: SharePreview("段取りラン \(Clock.text(record.seconds))", image: shareImage)) {
                    Label("結果を共有", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(LineButtonStyle())
                .frame(maxWidth: .infinity)
                Button("冷蔵庫を見る") {
                    dismiss()
                    model.tab = .fridge
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: shown) { _, new in model.hapticsOn && new ? .success : nil }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) { shown = true }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Text(Clock.text(record.seconds))
                    .font(Typo.number(76)).kerning(-3).monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                RankBadge(rank: record.rank, size: 64)
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
            }
            HStack(spacing: 8) {
                if isPB {
                    PBTag(text: previousBest == nil ? "このコースの初記録" : "自己ベスト更新")
                }
                if let previousBest, isPB {
                    Text("前より \(Clock.delta(record.seconds - previousBest.seconds))")
                        .font(.system(.footnote, design: .serif)).monospacedDigit().foregroundStyle(Palette.peachInk)
                } else if let previousBest {
                    Text("自己ベスト \(Clock.text(previousBest.seconds))")
                        .font(.system(.footnote, design: .serif)).monospacedDigit().foregroundStyle(Palette.sub)
                }
                Spacer(minLength: 0)
                Text(record.rank.title).font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink)
            }
        }
    }

    private var numbers: some View {
        HStack(alignment: .top, spacing: 0) {
            BigNumber(value: Clock.delta(record.parDelta), caption: "目安 \(Clock.text(record.parSeconds)) との差", size: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: String(format: "%.1f", record.speedup), unit: "倍速", caption: "1 品ずつ作るより", size: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(record.parallelRate)", unit: "%", caption: "2 つ以上が同時に", size: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panel(padding: 14)
    }

    private var dishes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(recipes) { recipe in
                    DishIcon(recipe: recipe, size: 40)
                }
            }
            Text("作った \(recipes.count) 品は冷蔵庫に入りました。期限までに全部食べきると、このランは「完食」になります。")
                .font(Typo.small).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var splits: some View {
        let route = self.route
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(kicker: "Splits", title: "スプリット")
            VStack(spacing: 0) {
                ForEach(Array(route.enumerated()), id: \.element.id) { index, step in
                    let delta = RunMath.splitDelta(route: route, taps: record.splits, index: index)
                    HStack(spacing: 10) {
                        Text(index < record.splits.count ? Clock.text(record.splits[index]) : "—")
                            .font(.system(size: 13, design: .serif)).monospacedDigit().foregroundStyle(Palette.ink)
                            .frame(width: 44, alignment: .trailing)
                        if let recipe = RecipeBook.recipe(step.planned.recipeID) { DishIcon(recipe: recipe, size: 24) }
                        Text(step.planned.step.text).font(.system(size: 13)).foregroundStyle(Palette.ink).lineLimit(1)
                        Spacer(minLength: 4)
                        if let delta {
                            Text(Clock.delta(delta)).font(.system(size: 12, design: .serif)).monospacedDigit()
                                .foregroundStyle(Palette.delta(delta))
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    if index < route.count - 1 { Divider().overlay(Palette.line).padding(.leading, 64) }
                }
            }
            .panel(padding: 4)
        }
    }

    @MainActor
    private var shareImage: Image {
        let renderer = ImageRenderer(content: ShareCard(record: record, recipes: recipes, isPB: isPB))
        renderer.scale = 3
        if let image = renderer.uiImage { return Image(uiImage: image) }
        return Image(systemName: "stopwatch")
    }
}

/// 共有カード（タイム・ランク・手際の数字と器だけ。名前や日付の細部は載せない）
struct ShareCard: View {
    let record: RunRecord
    let recipes: [Recipe]
    let isPB: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("段取りラン").font(.system(size: 13, weight: .medium)).kerning(0.6).foregroundStyle(Palette.sub)
                Spacer()
                if isPB { PBTag(text: "自己ベスト") }
            }
            HStack(alignment: .center) {
                Text(Clock.text(record.seconds)).font(Typo.number(64)).kerning(-3).monospacedDigit().foregroundStyle(Palette.ink)
                Spacer()
                RankBadge(rank: record.rank, size: 56)
            }
            HStack(spacing: 8) {
                ForEach(recipes) { recipe in DishIcon(recipe: recipe, size: 34) }
            }
            HStack(spacing: 18) {
                BigNumber(value: String(format: "%.1f", record.speedup), unit: "倍速", caption: "1 品ずつより", size: 22)
                BigNumber(value: "\(record.parallelRate)", unit: "%", caption: "並行", size: 22)
                BigNumber(value: "\(recipes.count)", unit: "品", caption: "作り置き", size: 22)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background {
            ZStack(alignment: .topTrailing) {
                Palette.ground
                Circle().fill(Palette.skySoft).frame(width: 220, height: 220).offset(x: 90, y: -90)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
