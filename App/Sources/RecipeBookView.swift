import SwiftUI

/// レシピ：作り置き 50 品。分類ごとの器の絵、時間・日持ち。押すとくわしく
struct RecipeBookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var category: RecipeCategory?
    @State private var detail: Recipe?
    @State private var tick = 0

    private var list: [Recipe] { RecipeBook.all.filter { category == nil || $0.category == category } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECIPES").smallLabel()
                    Text("作り置き \(RecipeBook.all.count) 品").font(Typo.serif(.title2)).foregroundStyle(Palette.ink)
                    Text("無料 \(RecipeBook.all.filter { !$0.isPro }.count) 品・器の形は分類（主菜・副菜・漬け・汁・お弁当・冷凍）")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                }
                CategoryChips(selection: $category)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 300 : 280), spacing: 10)], spacing: 0) {
                    ForEach(list) { recipe in
                        VStack(spacing: 0) {
                            RecipeRow(recipe: recipe, selected: model.selectedIDs.contains(recipe.id)) { add(recipe) }
                                .contentShape(Rectangle())
                                .onTapGesture { detail = recipe }
                            Divider().overlay(Palette.line).padding(.leading, 66)
                        }
                    }
                }
                .panel(padding: 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("レシピ")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $detail) { recipe in
            RecipeDetailView(recipe: recipe).environment(model).presentationBackground(Palette.ground)
        }
        .sensoryFeedback(trigger: tick) { _, _ in model.hapticsOn ? .selection : nil }
        .onAppear {
            if model.screenshotScene == "recipe" { detail = RecipeBook.recipe("chikuzen") }
        }
    }

    private func add(_ recipe: Recipe) {
        tick += 1
        switch model.toggle(recipe) {
        case .locked: model.offerPaywall(.lockedRecipe)
        case .full: if !model.isPro { model.offerPaywall(.dishLimit) }
        case .added, .removed: break
        }
    }
}

/// 分類の札（横にスクロール）
struct CategoryChips: View {
    @Binding var selection: RecipeCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, title: "すべて", vessel: nil)
                ForEach(RecipeCategory.allCases, id: \.self) { category in
                    chip(category, title: category.label, vessel: category.vessel)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ value: RecipeCategory?, title: String, vessel: Vessel?) -> some View {
        let on = selection == value
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { selection = value }
        } label: {
            HStack(spacing: 4) {
                if let vessel { DishIcon(vessel: vessel, tone: .veg, garnish: .dots, size: 20) }
                Text(title).font(.system(.footnote, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Palette.skyDeep : Palette.ink)
            .padding(.horizontal, 12).frame(minHeight: 36)
            .background(Capsule().fill(on ? Palette.skySoft : Palette.card))
            .overlay(Capsule().stroke(on ? Palette.sky : Palette.line, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// レシピの 1 行（器の絵・名前・時間と日持ち・コースに足すボタン）
struct RecipeRow: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    let selected: Bool
    let toggle: () -> Void

    var body: some View {
        let locked = !ProRules.canUse(recipe, isPro: model.isPro)
        HStack(spacing: 12) {
            DishIcon(recipe: recipe, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(recipe.name).font(.system(.subheadline, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                    if locked { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Palette.sub) }
                }
                Text("\(recipe.category.label)・\(recipe.totalMinutes) 分（手 \(recipe.handsMinutes)）・冷蔵 \(recipe.keepsDays) 日\(recipe.freezable ? "・冷凍可" : "")")
                    .font(.system(size: 11)).foregroundStyle(Palette.sub).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            Button(action: toggle) {
                Image(systemName: selected ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? .white : Palette.skyDeep)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(selected ? Palette.skyDeep : Palette.skySoft))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "\(recipe.name)をコースから外す" : "\(recipe.name)をコースに足す")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

/// レシピのくわしい画面
struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    var body: some View {
        let locked = !ProRules.canUse(recipe, isPro: model.isPro)
        let selected = model.selectedIDs.contains(recipe.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    DishIcon(recipe: recipe, size: 88)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.sub).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.category.label.uppercased()).smallLabel()
                    Text(recipe.name).font(Typo.serif(.largeTitle)).kerning(-1).foregroundStyle(Palette.ink)
                }
                HStack(spacing: 0) {
                    BigNumber(value: "\(recipe.totalMinutes)", unit: "分", caption: "1 品だけ作ると", size: 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BigNumber(value: "\(recipe.handsMinutes)", unit: "分", caption: "手を動かす", size: 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BigNumber(value: "\(recipe.keepsDays)", unit: "日", caption: "冷蔵のめやす", size: 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .panel(padding: 14)
                Text(recipe.freezable ? "冷凍できます（冷凍に回すと、そこから約 30 日）。\(recipe.portions) 食分。" : "冷凍には向きません。冷蔵で食べきりましょう。\(recipe.portions) 食分。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
                VStack(alignment: .leading, spacing: 0) {
                    Text("材料").font(Typo.serif(.headline)).foregroundStyle(Palette.ink).padding(.bottom, 6)
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        HStack {
                            Text(ingredient.name).font(Typo.body).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(ingredient.amount == 0 ? "適量" : ShoppingList.format(ingredient.amount) + ingredient.unit)
                                .font(.system(.footnote, design: .serif)).foregroundStyle(Palette.sub)
                        }
                        .padding(.vertical, 7)
                        Rectangle().fill(Palette.line).frame(height: 0.6)
                    }
                }
                .blur(radius: locked ? 4 : 0)
                VStack(alignment: .leading, spacing: 0) {
                    Text("工程").font(Typo.serif(.headline)).foregroundStyle(Palette.ink).padding(.bottom, 6)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .center, spacing: 10) {
                            LaneGlyph(kind: lane(step), size: 18)
                            Text(step.text).font(Typo.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Text(step.hands ? "\(step.minutes) 分" : "\(step.minutes) 分 待つ")
                                .font(.system(size: 11, design: .serif)).foregroundStyle(step.hands ? Palette.ink : Palette.skyDeep)
                                .fixedSize()
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(index + 1)、\(step.text)、\(step.minutes) 分")
                        Rectangle().fill(Palette.line).frame(height: 0.6)
                    }
                }
                .blur(radius: locked ? 4 : 0)
                if locked {
                    Button("Pro で開く") { dismiss(); model.offerPaywallSoon(.lockedRecipe) }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(selected ? "コースから外す" : "コースに足す") {
                        if model.toggle(recipe) == .full, !model.isPro { dismiss(); model.offerPaywallSoon(.dishLimit) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
    }

    private func lane(_ step: RecipeStep) -> LaneKind {
        switch step.device {
        case .burner: .burner(0)
        case .micro: .micro
        case .oven: .oven
        case .none: step.hands ? .hands : .wait(0)
        }
    }
}
