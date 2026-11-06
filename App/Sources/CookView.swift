import SwiftUI

/// 調理中：いまの工程を大きく、待っている工程と次の工程を小さく。全部できたら冷蔵庫に入れる
struct CookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepTick = 0
    @State private var finishTick = 0
    @State private var placed = false

    var body: some View {
        let plan = model.plan
        let remaining = plan.steps.filter { !model.cookedStepIDs.contains($0.id) }
        let current = remaining.first
        let parallel = CookProgress.running(plan: plan, cooked: model.cookedStepIDs)
        let upcoming = Array(remaining.dropFirst().prefix(3))

        VStack(spacing: 0) {
            topBar(done: plan.steps.count - remaining.count, total: plan.steps.count)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let current {
                        if sizeClass == .regular {
                            HStack(alignment: .top, spacing: 20) {
                                currentCard(current).frame(maxWidth: .infinity)
                                VStack(alignment: .leading, spacing: 18) {
                                    side(parallel: parallel, upcoming: upcoming)
                                }
                                .frame(width: 320)
                            }
                        } else {
                            currentCard(current)
                            side(parallel: parallel, upcoming: upcoming)
                        }
                    } else {
                        finished
                    }
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: stepTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: finishTick) { _, _ in model.hapticsOn ? .success : nil }
        .onAppear {
            if model.screenshotScene == "cook" {
                model.cookedStepIDs = Set(plan.steps.prefix(3).map(\.id))
            }
        }
    }

    private func topBar(done: Int, total: Int) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.medium)).foregroundStyle(Palette.sub).frame(width: 44, height: 44)
            }
            .accessibilityLabel("段取りを閉じる（進み具合は残ります）")
            Spacer()
            Text("\(done) / \(total)").font(.system(.subheadline, design: .serif)).monospacedDigit()
                .foregroundStyle(Palette.ink).contentTransition(.numericText())
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Capsule().fill(Palette.mint)
                    .frame(width: total == 0 ? 0 : geo.size.width * CGFloat(done) / CGFloat(total), height: 2)
            }
            .frame(height: 2)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: done)
    }

    private func currentCard(_ step: PlannedStep) -> some View {
        let index = model.selectedIDs.firstIndex(of: step.recipeID) ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("いま · \(Clock.text(step.start)) ごろ").smallLabel()
                Spacer()
                Text(StepTag.text(step.step)).font(Typo.label).foregroundStyle(Palette.sub)
            }
            TapeLabel(title: "\(Marker.circled(index)) \(step.recipeName)", tilt: -2)
            Text(step.step.text)
                .font(Typo.serif(.title, weight: .regular))
                .kerning(-0.5)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .id(step.id)
                .transition(.opacity.combined(with: .offset(y: 8)))
            if !step.step.hands {
                Text("火加減やタイマーをかけたら、手が空きます。次の工程に進みましょう。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
            }
            Button(step.step.hands ? "できた" : "始めた（待つあいだに次へ）") {
                stepTick += 1
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    _ = model.cookedStepIDs.insert(step.id)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(GridPaper().clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)))
        .background(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .softShadow()
    }

    @ViewBuilder
    private func side(parallel: [PlannedStep], upcoming: [PlannedStep]) -> some View {
        if !parallel.isEmpty {
            group(title: "並行して進んでいるもの", steps: parallel, running: true)
        }
        if !upcoming.isEmpty {
            group(title: "このあと", steps: upcoming, running: false)
        }
    }

    private func group(title: String, steps: [PlannedStep], running: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink).padding(.bottom, 6)
            ForEach(steps) { step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Clock.text(step.start)).font(.system(.footnote, design: .serif)).monospacedDigit()
                        .foregroundStyle(Palette.mintDeep).frame(width: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.recipeName).smallLabel()
                        Text(step.step.text).font(Typo.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if running {
                        Text("待っている").font(Typo.label).foregroundStyle(Palette.sub)
                    } else {
                    Button {
                        stepTick += 1
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { _ = model.cookedStepIDs.insert(step.id) }
                    } label: {
                        Image(systemName: "checkmark").font(.footnote.weight(.semibold)).foregroundStyle(Palette.mintDeep)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(step.step.text)を済みにする")
                    }
                }
                .padding(.vertical, 4)
                Rectangle().fill(Palette.line).frame(height: 0.6)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Text("できあがり").smallLabel()
            Text("\(model.selectedRecipes.count) 品、おつかれさまでした")
                .font(Typo.serif(.title2)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            // 容器が棚に並ぶ（置かれる瞬間だけ少し傾けて置く）
            let columns = [GridItem(.adaptive(minimum: 92), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(Array(model.selectedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    let item = FridgeItem(recipeID: recipe.id, name: recipe.name, madeOn: model.today, keepsDays: recipe.keepsDays,
                                          portions: recipe.portions, left: recipe.portions)
                    ContainerView(item: item, freshness: .fresh(recipe.keepsDays))
                        .rotationEffect(.degrees(placed || reduceMotion ? 0 : Double(index % 2 == 0 ? -4 : 4)))
                        .offset(y: placed || reduceMotion ? 0 : -10)
                        .opacity(placed || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85).delay(Double(index) * 0.08), value: placed)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
            Text("日持ちのめやすから、食べきる順に冷蔵庫に並べます。").font(Typo.small).foregroundStyle(Palette.sub)
            Button("冷蔵庫に入れる") {
                finishTick += 1
                model.finishCooking()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .onAppear { placed = true }
    }
}

/// 調理中の進み具合（画面から切り離してテストする）
enum CookProgress {
    /// 始めた「待つ」工程のうち、同じ品の次の工程がまだのもの（煮ている・漬けている最中）
    static func running(plan: Plan, cooked: Set<String>) -> [PlannedStep] {
        plan.steps.filter { step in
            guard !step.step.hands, cooked.contains(step.id) else { return false }
            let nextID = "\(step.recipeID)#\(step.stepIndex + 1)"
            let hasNext = plan.steps.contains { $0.id == nextID }
            return hasNext ? !cooked.contains(nextID) : !isFinished(plan: plan, cooked: cooked)
        }
    }

    static func isFinished(plan: Plan, cooked: Set<String>) -> Bool {
        plan.steps.allSatisfy { cooked.contains($0.id) }
    }
}
