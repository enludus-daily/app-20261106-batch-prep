import SwiftUI

/// ② 段取り：品を選ぶ → 買い物リスト → タイムライン → 調理
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var picking = false
    @State private var shopping = false
    @State private var cooking = false
    @State private var lockedTick = 0

    var body: some View {
        let plan = model.plan
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Heading(kicker: "Batch plan", title: model.selectedIDs.isEmpty ? "今週は、なにを作る？" : "\(model.selectedIDs.count) 品の段取り")
                if model.selectedIDs.isEmpty {
                    presets
                } else if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 20) {
                            dishes
                            summary(plan)
                            actions
                        }
                        .frame(width: 330)
                        VStack(alignment: .leading, spacing: 20) {
                            TimelineChart(plan: plan, order: model.selectedIDs, kitchen: model.kitchen)
                            StepList(plan: plan, order: model.selectedIDs)
                        }
                    }
                } else {
                    dishes
                    summary(plan)
                    TimelineChart(plan: plan, order: model.selectedIDs, kitchen: model.kitchen)
                    actions
                    StepList(plan: plan, order: model.selectedIDs)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sheet(isPresented: $picking) {
            NavigationStack { RecipeBookView(picking: true) }
                .presentationBackground(Palette.ground)
        }
        .sheet(isPresented: $shopping) {
            ShoppingView().presentationBackground(Palette.ground)
        }
        .fullScreenCover(isPresented: $cooking, onDismiss: {
            if model.pendingPaywall {
                model.pendingPaywall = false
                model.offerPaywall(.afterFirstPlan)
            }
        }) {
            CookView()
        }
        .sensoryFeedback(trigger: lockedTick) { _, _ in model.hapticsOn ? .warning : nil }
        .onAppear {
            switch model.screenshotScene {
            case "shopping": shopping = true
            case "cook": cooking = true
            default: break
            }
        }
    }

    // MARK: - 選んだ品

    private var dishes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("選んだ品").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(model.selectedIDs.count) / \(model.dishLimit) 品").font(Typo.small).monospacedDigit().foregroundStyle(Palette.sub)
            }
            FlowLayout(spacing: 8) {
                ForEach(Array(model.selectedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { _ = model.toggle(recipe) }
                    } label: {
                        HStack(spacing: 6) {
                            Text(Marker.circled(index)).font(.system(.footnote, design: .serif))
                            Text(recipe.name).font(.system(.footnote, design: .serif, weight: .medium))
                            Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.sub)
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(TapeShape().fill(Palette.tape.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(recipe.name)を外す")
                }
                Button { picking = true } label: {
                    Label("品を足す", systemImage: "plus").font(.system(.footnote, weight: .medium))
                }
                .buttonStyle(LineButtonStyle())
            }
            if model.plansCompleted == 0 && !model.isPro {
                Text("はじめての段取りは、8 品まで試せます。2 回目からは無料で 3 品まで。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
            }
        }
    }

    // MARK: - 合計の時間

    private func summary(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                BigNumber(value: "\(plan.totalMinutes)", unit: "分", caption: "段取りで")
                BigNumber(value: "\(plan.sequentialMinutes)", unit: "分", caption: "1 品ずつだと")
                BigNumber(value: "\(plan.handsMinutes)", unit: "分", caption: "手を動かす")
            }
            if plan.savedMinutes > 0 {
                Text("待つあいだに次の品を進めるので、\(plan.savedMinutes) 分みじかくなります（めやす）。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
            }
            HStack {
                Text("コンロ").font(Typo.small).foregroundStyle(Palette.ink)
                Spacer()
                Stepper(value: Binding(get: { model.kitchen.burners }, set: { model.kitchen.burners = $0 }), in: 1...3) {
                    Text("\(model.kitchen.burners) 口").font(.system(.footnote, design: .serif)).monospacedDigit()
                }
                .fixedSize()
            }
        }
        .animation(.easeOut(duration: 0.25), value: plan.totalMinutes)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("段取りをはじめる") { cooking = true }
                .buttonStyle(PrimaryButtonStyle())
            HStack(spacing: 10) {
                Button { shopping = true } label: { Label("買い物リスト", systemImage: "cart").frame(maxWidth: .infinity) }
                    .buttonStyle(LineButtonStyle())
                Button { picking = true } label: { Label("レシピ帳", systemImage: "book").frame(maxWidth: .infinity) }
                    .buttonStyle(LineButtonStyle())
            }
        }
    }

    // MARK: - 空のとき：おすすめの組み合わせ

    private var presets: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("何品か選ぶと、手・コンロ・レンジの空きから、まとめて作る順番が出ます。まずは組み合わせから。")
                .font(Typo.body).foregroundStyle(Palette.sub)
                .fixedSize(horizontal: false, vertical: true)
            let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RecipeBook.presets) { preset in
                    Button {
                        if !model.usePreset(preset) { lockedTick += 1; model.offerPaywall(.lockedRecipe) }
                    } label: {
                        PresetCard(preset: preset, locked: preset.isPro && !model.isPro)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { picking = true } label: { Label("レシピ帳から 1 品ずつ選ぶ", systemImage: "book").frame(maxWidth: .infinity) }
                .buttonStyle(LineButtonStyle())
        }
    }
}

struct PresetCard: View {
    let preset: Preset
    let locked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(preset.recipeIDs.count) 品").smallLabel()
                Spacer()
                if locked { Text("PRO").font(.system(size: 9, weight: .semibold)).kerning(0.8).foregroundStyle(Palette.mintDeep) }
            }
            Text(preset.title).font(Typo.serif(.headline)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            Text(preset.note).font(Typo.small).foregroundStyle(Palette.sub).lineLimit(2)
            let minutes = Scheduler.plan(preset.recipeIDs.compactMap(RecipeBook.recipe)).totalMinutes
            Text("段取りで約 \(minutes) 分").font(.system(.caption, design: .serif)).monospacedDigit().foregroundStyle(Palette.mintDeep)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .opacity(locked ? 0.75 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// 品の番号（選んだ順）
enum Marker {
    static func circled(_ index: Int) -> String {
        let marks = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧"]
        return index < marks.count ? marks[index] : "\(index + 1)"
    }
}

/// 方眼のメモに書いた段取りの帯（手・コンロ・レンジ・グリル・待ち）
struct TimelineChart: View {
    let plan: Plan
    let order: [String]
    let kitchen: KitchenSetup
    private let rowHeight: CGFloat = 30
    private let labelWidth: CGFloat = 52
    private let perMinute: CGFloat = 6

    private struct Lane: Identifiable {
        let id: String
        let title: String
        let steps: [PlannedStep]
    }

    private var lanes: [Lane] {
        var lanes = [Lane(id: "hands", title: "手", steps: plan.steps.filter(\.step.hands))]
        for i in 0..<kitchen.burners {
            lanes.append(Lane(id: "burner\(i)", title: "コンロ\(i + 1)", steps: plan.steps.filter { $0.step.device == .burner && $0.slot == i }))
        }
        let micro = plan.steps.filter { $0.step.device == .micro }
        if !micro.isEmpty { lanes.append(Lane(id: "micro", title: "レンジ", steps: micro)) }
        let oven = plan.steps.filter { $0.step.device == .oven }
        if !oven.isEmpty { lanes.append(Lane(id: "oven", title: "グリル", steps: oven)) }
        for row in 0..<plan.waitRows {
            lanes.append(Lane(id: "wait\(row)", title: row == 0 ? "待つ" : "", steps: plan.steps.filter { !$0.step.hands && $0.step.device == .none && $0.slot == row }))
        }
        return lanes
    }

    var body: some View {
        let width = CGFloat(max(plan.totalMinutes, 30)) * perMinute
        VStack(alignment: .leading, spacing: 8) {
            Text("タイムライン").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(width: labelWidth, height: 18)
                    ForEach(lanes) { lane in
                        Text(lane.title).font(Typo.label).foregroundStyle(Palette.sub)
                            .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                    }
                }
                .frame(width: labelWidth)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ruler(width: width)
                        ForEach(lanes) { lane in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Palette.line).frame(height: 0.6).frame(maxHeight: .infinity, alignment: .bottom)
                                ForEach(lane.steps) { step in bar(step) }
                            }
                            .frame(width: width, height: rowHeight)
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
            .padding(12)
            .background(GridPaper(spacing: 12).clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)))
            .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("タイムライン。\(order.count) 品を \(plan.totalMinutes) 分で作る段取り")
    }

    private func ruler(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(Array(stride(from: 0, through: max(plan.totalMinutes, 30), by: 10)), id: \.self) { minute in
                Text("\(minute)").font(.system(size: 9, design: .serif)).monospacedDigit().foregroundStyle(Palette.sub)
                    .offset(x: CGFloat(minute) * perMinute)
            }
        }
        .frame(width: width, height: 18, alignment: .leading)
    }

    private func bar(_ step: PlannedStep) -> some View {
        let index = order.firstIndex(of: step.recipeID) ?? 0
        let w = max(CGFloat(step.step.minutes) * perMinute - 2, 10)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(step.step.hands ? Palette.mint : Palette.mintSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Palette.mintDeep.opacity(step.step.hands ? 0 : 0.35), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
            )
            .overlay(alignment: .leading) {
                Text(w > 40 ? "\(Marker.circled(index))\(step.recipeName)" : Marker.circled(index))
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .frame(width: w, height: rowHeight - 8)
            .offset(x: CGFloat(step.start) * perMinute)
    }
}

/// 工程の一覧（始める時刻の順）
struct StepList: View {
    let plan: Plan
    let order: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("順番").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink).padding(.bottom, 8)
            ForEach(plan.steps) { step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Clock.text(step.start)).font(.system(.footnote, design: .serif)).monospacedDigit()
                        .foregroundStyle(Palette.mintDeep).frame(width: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Marker.circled(order.firstIndex(of: step.recipeID) ?? 0)) \(step.recipeName)").smallLabel()
                        Text(step.step.text).font(Typo.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Text(StepTag.text(step.step)).font(Typo.label).foregroundStyle(Palette.sub)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                Rectangle().fill(Palette.line).frame(height: 0.6)
            }
        }
    }
}

enum Clock {
    /// 経過の分を「0:05」の形に
    static func text(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
}

enum StepTag {
    static func text(_ step: RecipeStep) -> String {
        let kind = step.hands ? "手" : "待つ"
        let device = step.device == .none ? "" : "・" + step.device.label
        return "\(step.minutes)分 \(kind)\(device)"
    }
}

/// 札を折り返して並べる
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        // 折り返しを決めた幅をそのまま返す（狭い幅で置き直されて重ならないように）
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
