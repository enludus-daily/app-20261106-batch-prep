import SwiftUI

/// ラン中（調理中）の全画面。大きな経過時間・目安との差・ゴーストとの差・今の工程・大きな 1 つのボタン。
/// Duo の内側（regular）では、左にタイムラインとルート、右に今の工程を並べる。
struct RunView: View {
    @Environment(AppModel.self) private var model
    @State private var askQuit = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = model.screenshotScene != nil ? model.now : context.date
            if let session = model.session, let plan = model.sessionPlan {
                RunContent(session: session, plan: plan, now: now, askQuit: $askQuit)
            } else {
                Color.clear.onAppear { model.showRun = false }
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .confirmationDialog("ランをどうしますか", isPresented: $askQuit, titleVisibility: .visible) {
            Button("閉じる（あとで続きから）") { model.showRun = false }
            Button("このランをやめる", role: .destructive) { model.abandonRun() }
            Button("走りつづける", role: .cancel) {}
        }
    }
}

private struct RunContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: RunSession
    let plan: Plan
    let now: Date
    @Binding var askQuit: Bool

    private var route: [RouteStep] { RunMath.route(plan) }
    private var elapsed: Int { session.elapsed(at: now) }
    private var index: Int { session.taps.count }
    private var current: RouteStep? { index < route.count ? route[index] : nil }
    private var running: [RunningWait] { RunMath.running(route: route, taps: session.taps, now: elapsed) }
    private var best: RunRecord? { session.ghost ? model.sessionBest : nil }
    private var combo: Int { RunMath.combo(route: route, taps: session.taps) }

    /// 目安との差：最後に押した工程の差。今の工程が目安を過ぎていれば、その遅れ
    private var parDelta: Int? {
        let last = RunMath.splitDelta(route: route, taps: session.taps, index: index - 1)
        guard let current else { return last }
        let late = elapsed - current.checkpointMinutes * 60
        if late > 0 { return max(late, last ?? late) }
        return last
    }

    private var ghostDelta: Int? {
        guard let best else { return nil }
        if index < best.splits.count, elapsed > best.splits[index] {
            // 自己ベストのときは、もう次を押していた
            let previous = RunMath.ghostDelta(best: best, taps: session.taps) ?? 0
            return max(previous, elapsed - best.splits[index])
        }
        return RunMath.ghostDelta(best: best, taps: session.taps)
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            TimelineChart(plan: plan, order: session.recipeIDs,
                                          done: Set(route.prefix(index).map(\.id)), current: current?.id,
                                          nowMinutes: Double(elapsed) / 60)
                                .panel(padding: 14)
                            VStack(spacing: 0) {
                                ForEach(Array(route.enumerated()), id: \.element.id) { i, step in
                                    RouteRow(step: step, number: number(step), state: i < index ? .done : (i == index ? .current : .upcoming))
                                }
                            }
                            .panel(padding: 4)
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity)
                    mainColumn
                        .frame(width: 360)
                        .padding(.vertical, 20).padding(.trailing, 20)
                }
            } else {
                mainColumn.padding(.horizontal, 20).padding(.vertical, 8)
            }
        }
        .sensoryFeedback(trigger: index) { old, new in
            guard model.hapticsOn else { return nil }
            return new > old ? .impact(weight: .light, intensity: 0.7) : .selection
        }
        .sensoryFeedback(trigger: combo) { old, new in
            guard model.hapticsOn else { return nil }
            if new >= 2 && new > old { return .impact(weight: .heavy, intensity: min(1, 0.6 + Double(new) * 0.1)) }
            if old >= 2 && new == 0 { return .warning }
            return nil
        }
        .sensoryFeedback(trigger: running.count) { old, new in
            model.hapticsOn && new < old ? .success : nil
        }
    }

    private func laneKind(_ step: RouteStep) -> LaneKind {
        switch step.planned.step.device {
        case .burner: return .burner(step.planned.slot)
        case .micro: return .micro
        case .oven: return .oven
        case .none: return step.isWait ? .wait(0) : .hands
        }
    }

    private func number(_ step: RouteStep) -> Int { (session.recipeIDs.firstIndex(of: step.planned.recipeID) ?? 0) + 1 }

    // MARK: 右（または全体）の列

    private var mainColumn: some View {
        VStack(spacing: 14) {
            topBar
            timer
            if let current {
                currentCard(current)
                    .id(current.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                        removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                goalCard
            }
            runningList
            nextUp
            Spacer(minLength: 0)
            mainButton
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { askQuit = true } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.sub)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("閉じる・やめる")
            VStack(spacing: 4) {
                Text("\(min(index, route.count)) / \(route.count) 歩").font(.system(.caption, design: .serif)).monospacedDigit()
                    .foregroundStyle(Palette.sub)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule().fill(Palette.sky)
                            .frame(width: geo.size.width * CGFloat(min(index, route.count)) / CGFloat(max(route.count, 1)))
                    }
                }
                .frame(height: 4)
            }
            Button { model.undoTap() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 15, weight: .medium))
                    .foregroundStyle(index == 0 ? Palette.line : Palette.sub)
                    .frame(width: 44, height: 44)
            }
            .disabled(index == 0)
            .accessibilityLabel("1 つ前に戻す")
        }
    }

    private var timer: some View {
        VStack(spacing: 6) {
            Text(Clock.text(elapsed))
                .font(Typo.number(sizeClass == .regular ? 88 : 76))
                .kerning(-3)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityLabel("経過 \(elapsed / 60) 分 \(elapsed % 60) 秒")
            HStack(spacing: 8) {
                pill(title: "目安", value: parDelta, fallback: Clock.text(plan.totalMinutes * 60))
                if session.ghost, model.sessionBest != nil {
                    pill(title: "自己ベスト", value: ghostDelta, fallback: Clock.text(model.sessionBest?.seconds ?? 0), ghost: true)
                }
            }
            if combo >= 2 {
                Text("目安内 ×\(combo)")
                    .font(.system(size: 13, weight: .semibold, design: .serif)).monospacedDigit()
                    .foregroundStyle(Palette.peachInk)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(Palette.peachSoft))
                    .id(combo)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.4).combined(with: .opacity))
                    .accessibilityLabel("目安内の連続 \(combo)")
            }
        }
        .padding(.top, 4)
    }

    private func pill(title: String, value: Int?, fallback: String, ghost: Bool = false) -> some View {
        HStack(spacing: 5) {
            if ghost {
                Circle().stroke(Palette.peach, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2])).frame(width: 10, height: 10)
            }
            Text(title).font(.system(size: 11)).foregroundStyle(Palette.sub)
            Text(value.map(Clock.delta) ?? fallback)
                .font(.system(size: 14, design: .serif)).monospacedDigit()
                .foregroundStyle(value.map(Palette.delta) ?? Palette.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Palette.card))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }

    private func currentCard(_ step: RouteStep) -> some View {
        let recipe = RecipeBook.recipe(step.planned.recipeID)
        let late = elapsed - step.checkpointMinutes * 60
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let recipe { DishIcon(recipe: recipe, size: 44) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(step.isWait ? "仕掛ける" : "いま、手を動かす").font(Typo.label).kerning(0.6).foregroundStyle(Palette.peachInk)
                    Text("\(number(step))  \(step.planned.recipeName)").font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.ink).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("目安 \(Clock.text(step.checkpointMinutes * 60))").font(.system(size: 12, design: .serif)).monospacedDigit()
                    .foregroundStyle(late > 0 ? Palette.peachInk : Palette.sub)
            }
            Text(step.planned.step.text)
                .font(Typo.serif(.title2))
                .foregroundStyle(Palette.ink)
                .lineLimit(3).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                LaneGlyph(kind: laneKind(step), size: 16)
                Text(step.isWait ? "\(step.planned.step.minutes) 分 待つあいだに、次へ進めます" : "\(step.planned.step.minutes) 分のめやす")
                    .font(.system(size: 12)).foregroundStyle(Palette.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.peach.opacity(0.7), lineWidth: 1.2))
        .softShadow()
    }

    private var goalCard: some View {
        let finish = RunMath.finishSeconds(route: route, taps: session.taps) ?? elapsed
        let left = max(0, finish - elapsed)
        return VStack(spacing: 6) {
            Text(left > 0 ? "あとは待つだけ" : "全部できました").font(Typo.serif(.title2)).foregroundStyle(Palette.ink)
            Text(left > 0 ? "仕上がりまで \(Clock.text(left))。早く仕上がったら、ゴールを押してください。" : "ゴールを押して、タイムを確定します。")
                .font(Typo.small).foregroundStyle(Palette.sub).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .panel(padding: 18)
    }

    @ViewBuilder
    private var runningList: some View {
        let items = running
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("動いているもの").smallLabel()
                ForEach(items.prefix(3)) { item in
                    let total = item.step.planned.step.minutes * 60
                    let left = item.endsAt - elapsed
                    HStack(spacing: 10) {
                        if let recipe = RecipeBook.recipe(item.step.planned.recipeID) { DishIcon(recipe: recipe, size: 26) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.step.planned.step.text).font(.system(size: 12)).foregroundStyle(Palette.ink).lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Palette.skySoft)
                                    Capsule().fill(Palette.sky)
                                        .frame(width: geo.size.width * CGFloat(total - left) / CGFloat(max(total, 1)))
                                }
                            }
                            .frame(height: 4)
                        }
                        Text(Clock.text(left)).font(.system(size: 13, design: .serif)).monospacedDigit().foregroundStyle(Palette.skyDeep)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(padding: 14)
        }
    }

    /// このあと（次の 2 歩）
    @ViewBuilder
    private var nextUp: some View {
        let upcoming = Array(route.dropFirst(index + 1).prefix(sizeClass == .regular ? 0 : 2))
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("このあと").smallLabel()
                ForEach(upcoming) { step in
                    HStack(spacing: 10) {
                        if let recipe = RecipeBook.recipe(step.planned.recipeID) { DishIcon(recipe: recipe, size: 24) }
                        Text(step.planned.step.text).font(.system(size: 13)).foregroundStyle(Palette.ink).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Clock.text(step.checkpointMinutes * 60)).font(.system(size: 12, design: .serif)).monospacedDigit()
                            .foregroundStyle(Palette.sub)
                    }
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mainButton: some View {
        Button {
            if current == nil {
                model.finishRun()
            } else {
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { model.tap() }
            }
        } label: {
            Text(current == nil ? "ゴール" : (current?.isWait == true ? "仕掛けた" : "できた"))
                .font(.system(.title3, weight: .semibold))
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.bottom, 4)
    }
}
