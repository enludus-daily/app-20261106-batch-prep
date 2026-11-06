import SwiftUI

/// ① 冷蔵庫：棚に容器が並び、食べきりたい順に手前（上）から。食べた・捨てたを記録する
struct FridgeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: UUID?
    @State private var sheetItem: FridgeItem?

    private var items: [FridgeItem] { model.ledger.sorted(today: model.today, calendar: model.calendar) }
    private var columns: Int { sizeClass == .regular ? 4 : 3 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Heading(kicker: "Fridge · \(Self.dateText(model.today))", title: summary)
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        fridgeBox.frame(maxWidth: .infinity)
                        VStack(spacing: 20) {
                            if let item = items.first(where: { $0.id == selectedID }) {
                                ItemPanel(item: item) { selectedID = nil }
                            }
                            StatsPanel()
                        }
                        .frame(width: 330)
                    }
                } else {
                    fridgeBox
                    StatsPanel()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sheet(item: $sheetItem) { item in
            ItemPanel(item: item) { sheetItem = nil }
                .padding(.top, 8)
                .presentationDetents([.height(360), .medium])
                .presentationBackground(Palette.ground)
        }
        .onAppear {
            if model.screenshotScene == "fridgeDetail" { open(items.first) }
        }
    }

    private var summary: String {
        let urgent = items.filter { model.ledger.freshness(of: $0, today: model.today, calendar: model.calendar).level >= 1 }
        if items.isEmpty { return "冷蔵庫は、いま空っぽ" }
        if urgent.isEmpty { return "どれもまだ余裕があります" }
        return "今日食べきりたいのは \(urgent.count) 品"
    }

    private var fridgeBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                EmptyNote(title: "からっぽ",
                          message: "週末に何品か選ぶと、まとめて作る順番が出ます。作った容器はここに並び、食べきるまで見守ります。",
                          action: "段取りを組む") { model.tab = .plan }
                    .padding(.vertical, 24)
            } else {
                if items.contains(where: \.isSample) {
                    Text("見本の容器です。段取りで作ると入れ替わります。")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                        .padding(.bottom, 12)
                }
                let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(row) { item in
                            Button { open(item) } label: {
                                ContainerView(item: item,
                                              freshness: model.ledger.freshness(of: item, today: model.today, calendar: model.calendar),
                                              selected: selectedID == item.id)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                        ForEach(0..<(columns - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    ShelfLine()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .fill(Palette.paper)
                .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Palette.line, lineWidth: 1))
        )
        // 冷蔵庫のドアの取っ手
        .overlay(alignment: .topTrailing) {
            Capsule().fill(Palette.line).frame(width: 4, height: 46).offset(x: 9, y: 28).accessibilityHidden(true)
        }
        .softShadow()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: items)
    }

    private func open(_ item: FridgeItem?) {
        guard let item else { return }
        if sizeClass == .regular {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                selectedID = selectedID == item.id ? nil : item.id
            }
        } else {
            sheetItem = item
        }
    }

    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }
}

/// 容器の詳細と、食べた・捨てたの記録
struct ItemPanel: View {
    @Environment(AppModel.self) private var model
    let item: FridgeItem
    let close: () -> Void
    @State private var eatTick = 0
    @State private var doneTick = 0
    @State private var discardTick = 0

    private var current: FridgeItem? { model.ledger.items.first { $0.id == item.id } }
    private var recipe: Recipe? { RecipeBook.recipe(item.recipeID) }

    var body: some View {
        let shown = current ?? item
        let freshness = model.ledger.freshness(of: shown, today: model.today, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shown.frozen ? "冷凍中" : freshness.label).smallLabel()
                    Text(shown.name).font(Typo.serif(.title2)).kerning(-0.5).foregroundStyle(Palette.ink)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.footnote.weight(.medium)).foregroundStyle(Palette.sub)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("閉じる")
            }
            Text("\(shown.madeOn.formatted(.dateTime.month(.defaultDigits).day().locale(Locale(identifier: "ja_JP"))))に作った · めやす \(shown.keepsDays) 日")
                .font(Typo.small).foregroundStyle(Palette.sub)
            // 残りの食数（目盛り）
            HStack(spacing: 6) {
                ForEach(0..<shown.portions, id: \.self) { index in
                    Capsule()
                        .fill(index < shown.left ? Palette.mint : Palette.line)
                        .frame(height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("残り \(shown.left) 食 / \(shown.portions) 食")
            Text("残り \(shown.left) 食").font(.system(.footnote, design: .serif)).monospacedDigit().foregroundStyle(Palette.ink)
                .contentTransition(.numericText())

            if current != nil {
                Button("1 食たべた") {
                    eatTick += 1
                    model.ledger.eat(item.id, on: model.today, calendar: model.calendar)
                    if model.ledger.items.first(where: { $0.id == item.id }) == nil { doneTick += 1; close() }
                }
                .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 10) {
                    Button("食べきった") {
                        doneTick += 1
                        model.ledger.eatAll(item.id, on: model.today, calendar: model.calendar)
                        close()
                    }
                    .buttonStyle(LineButtonStyle())
                    if recipe?.freezable == true && !shown.frozen {
                        Button("冷凍に回す") {
                            eatTick += 1
                            model.ledger.freeze(item.id, on: model.today, calendar: model.calendar)
                        }
                        .buttonStyle(LineButtonStyle())
                    }
                    Spacer(minLength: 0)
                    Button("捨てた") {
                        discardTick += 1
                        model.ledger.discard(item.id, on: model.today, calendar: model.calendar)
                        close()
                    }
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .padding(.horizontal, 4)
        .sensoryFeedback(trigger: eatTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: doneTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: discardTick) { _, _ in model.hapticsOn ? .warning : nil }
    }
}

/// 積み上げ：食べきり率・捨てずに続いた日数・今週の食数と、食べきりカレンダー
struct StatsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let ledger = model.ledger
        let weeks = model.isPro ? ProRules.proHeatmapWeeks : ProRules.freeHeatmapWeeks
        let cells = ledger.heatmap(weeks: weeks, today: model.today, calendar: model.calendar)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                BigNumber(value: ledger.eatRate.map { "\($0)" } ?? "–", unit: "%", caption: "食べきり率")
                BigNumber(value: "\(ledger.daysWithoutWaste(today: model.today, calendar: model.calendar))", unit: "日", caption: "捨てずに")
                BigNumber(value: "\(ledger.eatenThisWeek(today: model.today, calendar: model.calendar))", unit: "食", caption: "この 7 日")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("食べきりカレンダー").font(Typo.serif(.subheadline)).foregroundStyle(Palette.ink)
                    Spacer()
                    if !model.isPro {
                        Button("1 年分を見る") { model.offerPaywall(.heatmap) }
                            .font(Typo.small).foregroundStyle(Palette.mintDeep)
                    }
                }
                HeatmapView(cells: cells)
                if ledger.totalEaten + ledger.totalDiscarded == 0 {
                    Text("食べた日が、ここに色で残ります。捨てた日は小さな印がつきます。")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                }
            }
        }
        .padding(18)
        .background(alignment: .topLeading) {
            GridPaper().clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        }
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .animation(.easeOut(duration: 0.25), value: ledger.totalEaten)
    }
}

struct HeatmapView: View {
    let cells: [HeatCell]
    private let size: CGFloat = 11
    private let gap: CGFloat = 2

    var body: some View {
        let weeks = cells.count / 7
        let eatenDays = cells.filter { $0.eaten > 0 }.count
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: gap) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { d in
                            let cell = cells[w * 7 + d]
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(cell.isFuture ? Color.clear : Palette.heat(cell.level))
                                .frame(width: size, height: size)
                                .overlay {
                                    if cell.discarded > 0 {
                                        Circle().fill(Palette.peach).frame(width: 4, height: 4)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .defaultScrollAnchor(.trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("直近 \(weeks) 週の食べきりカレンダー。食べた日は \(eatenDays) 日")
    }
}
