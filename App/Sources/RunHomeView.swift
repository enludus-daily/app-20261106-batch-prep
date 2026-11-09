import SwiftUI

/// ラン（ホーム）：今週のお題・組んだコース・積み上げ・これまでのラン
struct RunHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showPlan = false
    @State private var showSettings = false

    private var challenge: Preset { WeeklyChallenge.preset(for: model.today, calendar: model.calendar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.session != nil { runningCard }
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        challengeCard
                        VStack(spacing: 16) {
                            if !model.selectedIDs.isEmpty { courseCard }
                            statsRow
                        }
                    }
                } else {
                    if model.selectedIDs.isEmpty { challengeCard } else { courseCard }
                    statsRow
                    if !model.selectedIDs.isEmpty { challengeCard }
                }
                history
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: sizeClass == .regular ? 900 : 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            }
        }
        .navigationDestination(isPresented: $showPlan) { PlanView() }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .environment(model)
                .presentationBackground(Palette.ground)
        }
        .onAppear {
            if ["plan", "planBig", "shopping"].contains(model.screenshotScene ?? "") { showPlan = true }
            if model.screenshotScene == "settings" { showSettings = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.today.formatted(.dateTime.month().day().weekday(.wide)).uppercased()).smallLabel()
            Text("段取りラン").font(Typo.number(34)).kerning(-1).foregroundStyle(Palette.ink)
        }
        .padding(.top, 4)
    }

    private var runningCard: some View {
        Button { model.showRun = true } label: {
            HStack(spacing: 12) {
                Circle().fill(Palette.peach).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ラン中").font(Typo.label).kerning(0.6).foregroundStyle(Palette.peachInk)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Clock.text(model.session?.elapsed(at: model.now) ?? 0))
                            .font(Typo.number(26)).monospacedDigit().foregroundStyle(Palette.ink)
                    }
                }
                Spacer()
                Text("戻る").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Palette.skyDeep)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.sub)
            }
            .panel(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: 今週のお題

    private var challengeCard: some View {
        let key = RunMath.courseKey(challenge.recipeIDs)
        let recipes = challenge.recipeIDs.compactMap(RecipeBook.recipe)
        let plan = Scheduler.plan(recipes, kitchen: model.kitchen)
        let weekBest = WeeklyChallenge.runsThisWeek(model.runs, courseKey: key, today: model.today, calendar: model.calendar)
            .min { $0.seconds < $1.seconds }
        let allBest = RunMath.best(model.runs, courseKey: key)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今週のお題").font(Typo.label).kerning(0.6).foregroundStyle(Palette.peachInk)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.peachSoft))
                Spacer()
                Text("目安 \(Clock.text(plan.totalMinutes * 60))").font(.system(.footnote, design: .serif)).monospacedDigit()
                    .foregroundStyle(Palette.sub)
            }
            Text(challenge.title).font(Typo.serif(.title2)).foregroundStyle(Palette.ink)
            HStack(spacing: 10) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    VStack(spacing: 4) {
                        DishIcon(recipe: recipe, size: 52)
                        Text(recipe.name).font(.system(size: 11)).foregroundStyle(Palette.ink).lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(index + 1) \(recipe.name)")
                }
            }
            HStack(spacing: 18) {
                BigNumber(value: weekBest.map { Clock.text($0.seconds) } ?? "—", caption: "今週のベスト", size: 26)
                BigNumber(value: allBest.map { Clock.text($0.seconds) } ?? "—", caption: "自己ベスト", size: 26)
                BigNumber(value: "\(plan.sequentialMinutes)", unit: "分", caption: "1 品ずつだと", size: 26)
            }
            Button("このお題で走る") {
                if model.usePreset(challenge) { showPlan = true }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .panel(padding: 18)
    }

    // MARK: 組んだコース

    private var courseCard: some View {
        let recipes = model.selectedRecipes
        let plan = model.plan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("組んだコース").smallLabel()
                Spacer()
                Text("\(recipes.count) 品").font(Typo.small).foregroundStyle(Palette.sub)
            }
            HStack(spacing: -8) {
                ForEach(recipes) { recipe in
                    DishIcon(recipe: recipe, size: 40)
                        .background(Circle().fill(Palette.ground))
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Clock.text(plan.totalMinutes * 60)).font(Typo.number(28)).kerning(-1).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text("目安").font(Typo.label).foregroundStyle(Palette.sub)
                }
            }
            Text(recipes.map(\.name).joined(separator: "・")).font(Typo.small).foregroundStyle(Palette.sub).lineLimit(2)
            Button("コースを見て走る") { showPlan = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .panel(padding: 18)
    }

    // MARK: 積み上げ

    private var statsRow: some View {
        HStack(spacing: 0) {
            BigNumber(value: "\(model.runs.count)", unit: "本", caption: "走ったラン", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(model.savedMinutesTotal)", unit: "分", caption: "縮めた時間", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            BigNumber(value: "\(model.clearStreak)", unit: "連続", caption: "完食したラン", size: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panel(padding: 16)
    }

    // MARK: これまでのラン

    @ViewBuilder
    private var history: some View {
        let visible = ProRules.visibleHistory(model.runs, isPro: model.isPro)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(kicker: "History", title: "これまでのラン")
            if visible.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("まだランがありません").font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
                    Text("今週のお題で 1 本走ると、タイムとランクがここに残ります。").font(Typo.small).foregroundStyle(Palette.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel()
            } else {
                VStack(spacing: 0) {
                    ForEach(visible) { record in
                        Button { model.result = record } label: { RunRow(record: record) }
                            .buttonStyle(.plain)
                        if record.id != visible.last?.id { Divider().overlay(Palette.line).padding(.leading, 56) }
                    }
                }
                .panel(padding: 6)
                let hidden = model.runs.count - visible.count
                if hidden > 0 {
                    Button("前のラン \(hidden) 本は Pro で見られます") { model.offerPaywall(.history) }
                        .font(Typo.small).foregroundStyle(Palette.skyDeep).frame(minHeight: 44)
                }
            }
        }
    }
}

/// これまでのランの 1 行
struct RunRow: View {
    @Environment(AppModel.self) private var model
    let record: RunRecord

    var body: some View {
        let isPB = RunMath.isPersonalBest(record, in: model.runs)
        let status = model.status(of: record)
        HStack(spacing: 12) {
            RankBadge(rank: record.rank, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(Clock.text(record.seconds)).font(Typo.number(22)).kerning(-0.6).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    if isPB { PBTag() }
                }
                Text(record.names.joined(separator: "・")).font(.system(size: 12)).foregroundStyle(Palette.sub).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(record.date.formatted(.dateTime.month(.defaultDigits).day())).font(.system(size: 12, design: .serif))
                    .foregroundStyle(Palette.sub)
                eatLabel(status)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func eatLabel(_ status: EatStatus) -> some View {
        let text: String
        let color: Color
        switch status {
        case .eating: text = "食べている"; color = Palette.sub
        case .cleared: text = "完食"; color = Palette.skyDeep
        case .spoiled: text = "残した"; color = Palette.peachInk
        }
        return Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
    }
}
