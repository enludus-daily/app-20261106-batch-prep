import SwiftUI

/// コース：選んだ品・目安・タイムライン・ルート。下に「スタート」を固定（スクロールしなくても押せる）
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showPicker = false
    @State private var showShopping = false
    @State private var tick = 0

    var body: some View {
        let recipes = model.selectedRecipes
        let plan = model.plan
        Group {
            if recipes.isEmpty {
                ScrollView { emptyState.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity) }
            } else if sizeClass == .regular {
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            timelinePanel(plan, recipes: recipes)
                            routeList(plan)
                        }
                        .padding(20)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            chips(recipes)
                            numbers(plan)
                            controls(plan)
                        }
                        .padding(20)
                    }
                    .frame(width: 320)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        chips(recipes)
                        numbers(plan)
                        timelinePanel(plan, recipes: recipes)
                        routeList(plan)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    controls(plan)
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                        .background(.regularMaterial)
                }
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("コース")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showPicker = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("品を足す")
            }
        }
        .sheet(isPresented: $showPicker) {
            DishPicker().environment(model).presentationBackground(Palette.ground)
        }
        .sheet(isPresented: $showShopping) {
            ShoppingView().environment(model).presentationBackground(Palette.ground)
        }
        .sensoryFeedback(trigger: tick) { _, _ in model.hapticsOn ? .selection : nil }
        .onAppear {
            if model.screenshotScene == "shopping" { showShopping = true }
        }
    }

    // MARK: 空のとき

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(kicker: "Course", title: "走るコースを選ぶ")
            Text("作り置きを何品か選ぶと、手・コンロ・レンジの空きから「まとめて作る順番（ルート）」を出します。そのルートを走って、目安と自己ベストに挑みます。")
                .font(Typo.body).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            ForEach(RecipeBook.presets) { preset in
                PresetRow(preset: preset) {
                    tick += 1
                    if !model.usePreset(preset) { model.offerPaywall(.lockedRecipe) }
                }
            }
            Button("レシピから 1 品ずつ選ぶ") { showPicker = true }.buttonStyle(LineButtonStyle())
        }
    }

    // MARK: 品の札

    private func chips(_ recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("選んだ品").smallLabel()
                Spacer()
                Text("\(recipes.count) / \(model.dishLimit) 品").font(.system(.caption, design: .serif)).monospacedDigit()
                    .foregroundStyle(Palette.sub)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                        DishChip(recipe: recipe, number: index + 1) {
                            tick += 1
                            withAnimation(.easeOut(duration: 0.2)) { _ = model.toggle(recipe) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: 数字

    private func numbers(_ plan: Plan) -> some View {
        HStack(alignment: .top, spacing: 0) {
            BigNumber(value: Clock.text(plan.totalMinutes * 60), caption: "目安", size: 34)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(plan.sequentialMinutes)", unit: "分", caption: "1 品ずつだと", size: 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: model.courseBest.map { Clock.text($0.seconds) } ?? "—", caption: "自己ベスト", size: 26)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: タイムライン

    private func timelinePanel(_ plan: Plan, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("タイムライン（分）").smallLabel()
                Spacer()
                legend(fill: Palette.sky, text: "手を動かす")
                legend(fill: Palette.skySoft, text: "待つ")
            }
            TimelineChart(plan: plan, order: recipes.map(\.id))
        }
        .panel(padding: 14)
    }

    private func legend(fill: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(fill).frame(width: 14, height: 9)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.sky, lineWidth: 0.6))
            Text(text).font(.system(size: 10)).foregroundStyle(Palette.sub)
        }
    }

    // MARK: ルート

    private func routeList(_ plan: Plan) -> some View {
        let route = RunMath.route(plan)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(kicker: "Route", title: "ルート \(route.count) 歩")
                Text("目安の時刻").font(Typo.label).foregroundStyle(Palette.sub)
            }
            VStack(spacing: 0) {
                ForEach(Array(route.enumerated()), id: \.element.id) { index, step in
                    RouteRow(step: step, number: number(of: step), state: .upcoming)
                    if index < route.count - 1 { Divider().overlay(Palette.line).padding(.leading, 92) }
                }
            }
            .panel(padding: 4)
        }
    }

    private func number(of step: RouteStep) -> Int {
        (model.selectedIDs.firstIndex(of: step.planned.recipeID) ?? 0) + 1
    }

    // MARK: 下の操作

    private func controls(_ plan: Plan) -> some View {
        @Bindable var model = model
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    LaneGlyph(kind: .burner(0), size: 16)
                    Text("コンロ \(model.kitchen.burners) 口").font(.system(.footnote, weight: .medium)).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Stepper("コンロの口の数", value: $model.kitchen.burners, in: 1...3)
                        .labelsHidden()
                        .scaleEffect(0.85)
                }
                Spacer(minLength: 4)
                Button { showShopping = true } label: {
                    Label("買い物", systemImage: "cart").font(.system(.footnote, weight: .medium))
                }
                .buttonStyle(LineButtonStyle())
            }
            if model.courseBest != nil {
                Text(model.canUseGhost ? (model.isPro ? "自己ベストのゴーストと走ります" : "自己ベストのゴーストを 1 回お試しで使えます")
                     : "ゴースト（自己ベストとの差）は Pro で")
                    .font(.system(size: 12)).foregroundStyle(model.canUseGhost ? Palette.peachInk : Palette.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                model.startRun()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                    Text("スタート")
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !plan.isEmpty))
            .disabled(plan.isEmpty)
        }
    }
}

/// ルートの 1 歩
struct RouteRow: View {
    enum Phase { case upcoming, done, current }
    let step: RouteStep
    let number: Int
    let state: Phase

    var body: some View {
        let recipe = RecipeBook.recipe(step.planned.recipeID)
        HStack(alignment: .center, spacing: 10) {
            Text(Clock.text(step.checkpointMinutes * 60))
                .font(.system(size: 13, design: .serif)).monospacedDigit()
                .foregroundStyle(state == .current ? Palette.peachInk : Palette.sub)
                .frame(width: 40, alignment: .trailing)
            ZStack(alignment: .bottomTrailing) {
                if let recipe { DishIcon(recipe: recipe, size: 32) }
                Text("\(number)").font(.system(size: 10, weight: .semibold, design: .serif)).foregroundStyle(.white)
                    .frame(width: 15, height: 15).background(Circle().fill(Palette.skyDeep))
                    .offset(x: 3, y: 2)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.planned.step.text).font(.system(.subheadline)).foregroundStyle(state == .done ? Palette.sub : Palette.ink)
                    .strikethrough(state == .done, color: Palette.sub)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text(step.planned.recipeName)
                    Text("・")
                    Text(step.isWait ? "\(step.planned.step.minutes) 分 待つ" : "\(step.planned.step.minutes) 分")
                    if step.planned.step.device != .none { Text("・\(step.planned.step.device.label)") }
                }
                .font(.system(size: 11)).foregroundStyle(Palette.sub).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(step.isWait ? "仕掛ける" : "手")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(step.isWait ? Palette.skyDeep : .white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(step.isWait ? Palette.skySoft : Palette.sky))
                .fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 9)
        .background(state == .current ? Palette.peachSoft.opacity(0.6) : .clear)
        .accessibilityElement(children: .combine)
    }
}

/// おすすめの組み合わせの 1 行
struct PresetRow: View {
    @Environment(AppModel.self) private var model
    let preset: Preset
    let action: () -> Void

    var body: some View {
        let recipes = preset.recipeIDs.compactMap(RecipeBook.recipe)
        let plan = Scheduler.plan(recipes, kitchen: model.kitchen)
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: -10) {
                    ForEach(recipes.prefix(4)) { recipe in
                        DishIcon(recipe: recipe, size: 34).background(Circle().fill(Palette.ground))
                    }
                }
                .frame(width: 96, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(preset.title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Palette.ink)
                        if preset.isPro && !model.isPro {
                            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Palette.sub)
                        }
                    }
                    Text(preset.note).font(.system(size: 12)).foregroundStyle(Palette.sub).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Clock.text(plan.totalMinutes * 60)).font(.system(.callout, design: .serif)).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text("\(recipes.count) 品").font(.system(size: 10)).foregroundStyle(Palette.sub)
                }
            }
            .panel(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint(preset.isPro && !model.isPro ? "Pro で開きます" : "このコースにする")
    }
}

/// 品を足す：組み合わせとレシピの一覧
struct DishPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var category: RecipeCategory?
    @State private var note: String?
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CategoryChips(selection: $category)
                    if let note {
                        Text(note).font(Typo.small).foregroundStyle(Palette.peachInk)
                    }
                    VStack(spacing: 0) {
                        let list = RecipeBook.all.filter { category == nil || $0.category == category }
                        ForEach(list) { recipe in
                            RecipeRow(recipe: recipe, selected: model.selectedIDs.contains(recipe.id)) { toggle(recipe) }
                            if recipe.id != list.last?.id { Divider().overlay(Palette.line).padding(.leading, 66) }
                        }
                    }
                    .panel(padding: 4)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("品を足す（\(model.selectedIDs.count) / \(model.dishLimit)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("できた") { dismiss() } }
            }
        }
        .sensoryFeedback(trigger: tick) { _, _ in model.hapticsOn ? .selection : nil }
    }

    private func toggle(_ recipe: Recipe) {
        tick += 1
        switch model.toggle(recipe) {
        case .added, .removed: note = nil
        case .locked:
            dismiss()
            model.offerPaywallSoon(.lockedRecipe)
        case .full:
            note = model.isPro ? "1 回のランは \(ProRules.proDishLimit) 品までです。" : "無料では 1 回に \(ProRules.freeDishLimit) 品まで。Pro で 8 品まで走れます。"
        }
    }
}
