import SwiftUI

/// 冷蔵庫：ランで作った品が並ぶ。期限が近い順。食べきるとそのランが「完食」になる
struct FridgeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheetItem: FridgeItem?
    @State private var tick = 0

    private var items: [FridgeItem] { model.ledger.sorted(today: model.today, calendar: model.calendar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FRIDGE").smallLabel()
                    Text(summary).font(Typo.serif(.title2)).foregroundStyle(Palette.ink)
                }
                stats
                if items.isEmpty {
                    EmptyNote(title: "冷蔵庫は空っぽ",
                              message: "ランを走ってゴールすると、作った品がここに並びます。期限までに食べきると、そのランが「完食」になります。",
                              action: "今週のお題を見る") { model.tab = .run }
                } else {
                    if items.contains(where: \.isSample) {
                        Text("見本の品です。ランで作ると入れ替わります。").font(Typo.small).foregroundStyle(Palette.sub)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 4 : 2),
                              spacing: 12) {
                        ForEach(items) { item in
                            Button { sheetItem = item } label: { FoodCard(item: item) }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: items)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("冷蔵庫")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $sheetItem) { item in
            ItemSheet(item: item) { sheetItem = nil }
                .environment(model)
                .presentationDetents([.height(400)])
                .presentationBackground(Palette.ground)
        }
        .onAppear {
            if model.screenshotScene == "fridgeDetail" { sheetItem = items.first }
        }
    }

    private var summary: String {
        let urgent = items.filter { model.ledger.freshness(of: $0, today: model.today, calendar: model.calendar).level >= 1 }
        if items.isEmpty { return "いまは空っぽ" }
        if urgent.isEmpty { return "どれもまだ余裕があります" }
        return "今日食べきりたいのは \(urgent.count) 品"
    }

    private var stats: some View {
        HStack(spacing: 0) {
            BigNumber(value: model.ledger.eatRate.map { "\($0)" } ?? "—", unit: "%", caption: "食べきり率", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(model.ledger.daysWithoutWaste(today: model.today, calendar: model.calendar))", unit: "日",
                      caption: "捨てずに", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(model.clearStreak)", unit: "連続", caption: "完食したラン", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panel(padding: 16)
    }
}

/// 冷蔵庫の 1 品（器の絵・名前・あと何日・残りの食数）
struct FoodCard: View {
    @Environment(AppModel.self) private var model
    let item: FridgeItem

    var body: some View {
        let recipe = RecipeBook.recipe(item.recipeID)
        let fresh = model.ledger.freshness(of: item, today: model.today, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if let recipe { DishIcon(recipe: recipe, size: 52) }
                Spacer(minLength: 0)
                Text(item.frozen ? "冷凍" : fresh.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(fresh.level >= 2 ? Palette.peachInk : Palette.skyDeep)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(fresh.level >= 2 ? Palette.peachSoft : Palette.skySoft))
                    .fixedSize()
            }
            Text(item.name).font(.system(.subheadline, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 3) {
                ForEach(0..<item.portions, id: \.self) { index in
                    Capsule().fill(index < item.left ? Palette.freshness(fresh) : Palette.line)
                        .frame(height: 5)
                }
            }
            Text("残り \(item.left) 食").font(.system(size: 11)).foregroundStyle(Palette.sub)
        }
        .panel(padding: 12)
        .accessibilityElement(children: .combine)
        .accessibilityHint("記録する")
    }
}

/// 1 品の記録：1 食たべた・食べきった・冷凍・捨てた
struct ItemSheet: View {
    @Environment(AppModel.self) private var model
    let item: FridgeItem
    let close: () -> Void
    @State private var tick = 0

    var body: some View {
        let recipe = RecipeBook.recipe(item.recipeID)
        let fresh = model.ledger.freshness(of: item, today: model.today, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                if let recipe { DishIcon(recipe: recipe, size: 64) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(Typo.serif(.title2)).foregroundStyle(Palette.ink)
                    Text("\(item.madeOn.formatted(.dateTime.month(.defaultDigits).day())) に作った・\(item.frozen ? "冷凍中" : fresh.label)・残り \(item.left) 食")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                }
            }
            if item.runID != nil {
                Text("全部食べきると、このランが「完食」になります。").font(.system(size: 12)).foregroundStyle(Palette.skyDeep)
            }
            Button("1 食たべた") { act { model.ledger.eat(item.id, on: model.today, calendar: model.calendar) } }
                .buttonStyle(PrimaryButtonStyle())
            HStack(spacing: 10) {
                Button("食べきった") { act { model.ledger.eatAll(item.id, on: model.today, calendar: model.calendar) } }
                    .buttonStyle(LineButtonStyle())
                if !item.frozen, recipe?.freezable ?? false {
                    Button("冷凍する") { act { model.ledger.freeze(item.id, on: model.today, calendar: model.calendar) } }
                        .buttonStyle(LineButtonStyle())
                }
                Spacer(minLength: 0)
                Button("捨てた", role: .destructive) { act { model.ledger.discard(item.id, on: model.today, calendar: model.calendar) } }
                    .font(.system(.subheadline)).foregroundStyle(Palette.peachInk).frame(minHeight: 44)
            }
            if recipe?.freezable == false && !item.frozen {
                Text("この品は冷凍に向きません。").font(.system(size: 11)).foregroundStyle(Palette.sub)
            }
        }
        .padding(22)
        .sensoryFeedback(trigger: tick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
    }

    private func act(_ change: () -> Void) {
        tick += 1
        change()
        close()
    }
}
