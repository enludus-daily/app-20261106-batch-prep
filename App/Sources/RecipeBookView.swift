import SwiftUI

/// ③ レシピ帳：分類ごとに。段取りに入れる・外す。Pro の束には印
struct RecipeBookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var picking = false
    @State private var category: RecipeCategory?
    @State private var detail: Recipe?
    @State private var addTick = 0
    @State private var blockTick = 0
    @State private var notice: String?

    private var recipes: [Recipe] {
        RecipeBook.all.filter { category == nil || $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Heading(kicker: "Recipe book", title: picking ? "段取りに入れる品" : "作り置きのレシピ帳")
                Text("\(RecipeBook.all.count) 品 · 無料 \(RecipeBook.all.filter { !$0.isPro }.count) 品 · 日持ちと冷凍のめやすつき")
                    .font(Typo.small).foregroundStyle(Palette.sub)
                filters
                if let notice {
                    Text(notice).font(Typo.small).foregroundStyle(Palette.mintDeep).transition(.opacity)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 0) {
                    ForEach(recipes) { recipe in row(recipe) }
                }
            }
            .padding(20)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .toolbar {
            if picking {
                ToolbarItem(placement: .confirmationAction) {
                    Button("できた（\(model.selectedIDs.count) 品）") { dismiss() }.tint(Palette.mintDeep)
                }
            }
        }
        .sheet(item: $detail) { recipe in
            RecipeDetailView(recipe: recipe).presentationBackground(Palette.ground)
        }
        .sensoryFeedback(trigger: addTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: blockTick) { _, _ in model.hapticsOn ? .warning : nil }
        .onAppear {
            if model.screenshotScene == "recipe" { detail = RecipeBook.recipe("chikuzen") }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, title: "すべて")
                ForEach(RecipeCategory.allCases, id: \.self) { c in chip(c, title: c.label) }
            }
        }
    }

    private func chip(_ value: RecipeCategory?, title: String) -> some View {
        let on = category == value
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { category = value }
        } label: {
            Text(title)
                .font(.system(.footnote, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Palette.mintDeep : Palette.sub)
                .padding(.horizontal, 12).frame(minHeight: 36)
                .background(Capsule().fill(on ? Palette.mintSoft : Color.clear))
                .overlay(Capsule().stroke(on ? Color.clear : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func row(_ recipe: Recipe) -> some View {
        let selected = model.selectedIDs.contains(recipe.id)
        let locked = !ProRules.canUse(recipe, isPro: model.isPro)
        return HStack(alignment: .center, spacing: 12) {
            Button { detail = recipe } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(recipe.category.label).smallLabel()
                        if recipe.isPro {
                            Text("PRO").font(.system(size: 9, weight: .semibold)).kerning(0.8).foregroundStyle(Palette.mintDeep)
                        }
                    }
                    Text(recipe.name).font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
                    Text("\(recipe.totalMinutes) 分 · 冷蔵 \(recipe.keepsDays) 日\(recipe.freezable ? " · 冷凍できる" : "") · \(recipe.portions) 食")
                        .font(Typo.label).foregroundStyle(Palette.sub).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { toggle(recipe) } label: {
                Image(systemName: locked ? "lock" : (selected ? "checkmark.circle.fill" : "plus.circle"))
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.mintDeep : Palette.sub)
                    .frame(width: 44, height: 44)
                    .symbolEffect(.bounce, value: selected)
            }
            .accessibilityLabel(locked ? "\(recipe.name)は Pro" : (selected ? "\(recipe.name)を段取りから外す" : "\(recipe.name)を段取りに入れる"))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 0.6) }
        .opacity(locked ? 0.7 : 1)
    }

    private func toggle(_ recipe: Recipe) {
        switch model.toggle(recipe) {
        case .added, .removed:
            addTick += 1
            withAnimation { notice = nil }
        case .locked:
            blockTick += 1
            model.offerPaywall(.lockedRecipe)
        case .full:
            blockTick += 1
            if model.isPro {
                withAnimation { notice = "1 回の段取りは \(ProRules.proDishLimit) 品までです。" }
            } else {
                model.offerPaywall(.dishLimit)
            }
        }
    }
}

struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    var body: some View {
        let locked = !ProRules.canUse(recipe, isPro: model.isPro)
        let selected = model.selectedIDs.contains(recipe.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.sub).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                TapeLabel(title: recipe.category.label, tilt: -4)
                Text(recipe.name).font(Typo.serif(.largeTitle)).kerning(-1).foregroundStyle(Palette.ink)
                HStack(spacing: 18) {
                    BigNumber(value: "\(recipe.totalMinutes)", unit: "分", caption: "ひとりで作ると")
                    BigNumber(value: "\(recipe.keepsDays)", unit: "日", caption: "冷蔵のめやす")
                    BigNumber(value: "\(recipe.portions)", unit: "食", caption: "できる量")
                }
                Text(recipe.freezable ? "冷凍できます（冷凍に回すと、そこから約 30 日）。" : "冷凍には向きません。冷蔵で食べきりましょう。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
                VStack(alignment: .leading, spacing: 0) {
                    Text("材料").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink).padding(.bottom, 6)
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        HStack {
                            Text(ingredient.name).font(Typo.body).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(ingredient.amount == 0 ? "適量" : ShoppingList.format(ingredient.amount) + ingredient.unit)
                                .font(.system(.footnote, design: .serif)).foregroundStyle(Palette.sub)
                        }
                        .padding(.vertical, 6)
                        Rectangle().fill(Palette.line).frame(height: 0.6)
                    }
                }
                .blur(radius: locked ? 3 : 0)
                VStack(alignment: .leading, spacing: 0) {
                    Text("工程").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink).padding(.bottom, 6)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)").font(.system(.footnote, design: .serif)).foregroundStyle(Palette.mintDeep).frame(width: 18)
                            Text(step.text).font(Typo.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Text(StepTag.text(step)).font(Typo.label).foregroundStyle(Palette.sub)
                        }
                        .padding(.vertical, 6)
                        Rectangle().fill(Palette.line).frame(height: 0.6)
                    }
                }
                .blur(radius: locked ? 3 : 0)
                if locked {
                    Button("Pro で開く") { dismiss(); model.offerPaywall(.lockedRecipe) }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(selected ? "段取りから外す" : "段取りに入れる") {
                        if model.toggle(recipe) == .full, !model.isPro { dismiss(); model.offerPaywall(.dishLimit) }
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
}
