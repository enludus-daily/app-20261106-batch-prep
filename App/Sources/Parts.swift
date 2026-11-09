import SwiftUI

// 世界観の部品。このアプリでは〔器〕が〔品の印〕に、〔まな板・コンロの口・レンジ〕が〔タイムラインのレーン〕になる。
// どれも自作の Canvas で描く（SF Symbols の置き換えにしない）。

// MARK: - 品の印（分類ごとに違う器 ＋ 品ごとの具の形 ＋ 中身の色）

struct DishIcon: View {
    let vessel: Vessel
    let tone: FoodTone
    let topping: Topping
    var size: CGFloat = 40

    init(recipe: Recipe, size: CGFloat = 40) {
        vessel = recipe.category.vessel
        tone = recipe.foodTone
        topping = recipe.topping
        self.size = size
    }

    init(vessel: Vessel, tone: FoodTone, topping: Topping, size: CGFloat = 40) {
        self.vessel = vessel
        self.tone = tone
        self.topping = topping
        self.size = size
    }

    var body: some View {
        Canvas { context, canvas in
            DishPainter(vessel: vessel, tone: tone, topping: topping, size: canvas).draw(in: &context)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct DishPainter {
    let vessel: Vessel
    let tone: FoodTone
    let topping: Topping
    let size: CGSize

    var food: Color {
        switch tone {
        case .meat: Palette.foodMeat
        case .veg: Palette.foodVeg
        case .egg: Palette.foodEgg
        }
    }

    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
    }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }

    var lineWidth: CGFloat { max(1, size.width / 34) }
    var outline: Color { Palette.skyDeep.opacity(0.75) }

    func draw(in context: inout GraphicsContext) {
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        var center = p(0.5, 0.5)
        var scale: CGFloat = 1
        switch vessel {
        case .plate:
            // 浅い深皿：楕円の皿に、こんもりした主菜
            let plate = Path(ellipseIn: r(0.04, 0.5, 0.92, 0.34))
            context.fill(plate, with: .color(Palette.card))
            context.stroke(plate, with: .color(outline), style: stroke)
            context.stroke(Path(ellipseIn: r(0.2, 0.57, 0.6, 0.18)), with: .color(Palette.line), style: stroke)
            var mound = Path()
            mound.move(to: p(0.22, 0.66))
            mound.addQuadCurve(to: p(0.78, 0.66), control: p(0.5, 0.2))
            mound.addQuadCurve(to: p(0.22, 0.66), control: p(0.5, 0.76))
            context.fill(mound, with: .color(food.opacity(0.5)))
            center = p(0.5, 0.56)
        case .bowl:
            // 小鉢：丸い鉢から副菜が少し盛り上がる
            context.fill(Path(ellipseIn: r(0.2, 0.3, 0.6, 0.34)), with: .color(food.opacity(0.5)))
            var bowl = Path()
            bowl.move(to: p(0.12, 0.5))
            bowl.addLine(to: p(0.88, 0.5))
            bowl.addQuadCurve(to: p(0.5, 0.9), control: p(0.86, 0.88))
            bowl.addQuadCurve(to: p(0.12, 0.5), control: p(0.14, 0.88))
            bowl.closeSubpath()
            context.fill(bowl, with: .color(Palette.card))
            context.stroke(bowl, with: .color(outline), style: stroke)
            center = p(0.5, 0.42)
            scale = 0.9
        case .cup:
            // 汁椀：高台つきの椀、汁の面と湯気
            var cup = Path()
            cup.move(to: p(0.14, 0.42))
            cup.addLine(to: p(0.86, 0.42))
            cup.addQuadCurve(to: p(0.5, 0.84), control: p(0.84, 0.82))
            cup.addQuadCurve(to: p(0.14, 0.42), control: p(0.16, 0.82))
            cup.closeSubpath()
            let foot = Path(roundedRect: r(0.36, 0.82, 0.28, 0.08), cornerRadius: lineWidth)
            context.fill(foot, with: .color(Palette.card))
            context.stroke(foot, with: .color(outline), style: stroke)
            context.fill(cup, with: .color(Palette.card))
            context.stroke(cup, with: .color(outline), style: stroke)
            let surface = Path(ellipseIn: r(0.17, 0.37, 0.66, 0.11))
            context.fill(surface, with: .color(food.opacity(0.6)))
            context.stroke(surface, with: .color(outline), style: stroke)
            for x in [0.42, 0.58] as [CGFloat] {
                var steam = Path()
                steam.move(to: p(x, 0.3))
                steam.addQuadCurve(to: p(x, 0.12), control: p(x + 0.07, 0.21))
                context.stroke(steam, with: .color(Palette.sub.opacity(0.6)), style: stroke)
            }
            center = p(0.5, 0.42)
            scale = 0.62
        case .jar:
            // 保存瓶：ふたと、漬けた中身
            let lid = Path(roundedRect: r(0.3, 0.1, 0.4, 0.13), cornerRadius: lineWidth * 1.5)
            context.fill(lid, with: .color(Palette.skySoft))
            context.stroke(lid, with: .color(outline), style: stroke)
            let body = Path(roundedRect: r(0.22, 0.23, 0.56, 0.67), cornerRadius: size.width * 0.12)
            context.fill(body, with: .color(Palette.card))
            context.fill(Path(roundedRect: r(0.27, 0.48, 0.46, 0.37), cornerRadius: size.width * 0.08), with: .color(food.opacity(0.5)))
            context.stroke(body, with: .color(outline), style: stroke)
            center = p(0.5, 0.66)
            scale = 0.72
        case .bento:
            // 弁当箱：仕切りの左にごはん、右におかず
            let box = Path(roundedRect: r(0.07, 0.28, 0.86, 0.52), cornerRadius: size.width * 0.1)
            context.fill(box, with: .color(Palette.card))
            context.fill(Path(roundedRect: r(0.12, 0.33, 0.35, 0.42), cornerRadius: size.width * 0.06), with: .color(Palette.skySoft))
            context.fill(Path(roundedRect: r(0.53, 0.33, 0.35, 0.42), cornerRadius: size.width * 0.06), with: .color(food.opacity(0.5)))
            var divider = Path()
            divider.move(to: p(0.5, 0.3))
            divider.addLine(to: p(0.5, 0.78))
            context.stroke(divider, with: .color(outline), style: stroke)
            context.stroke(box, with: .color(outline), style: stroke)
            center = p(0.705, 0.54)
            scale = 0.6
        case .bag:
            // 冷凍の保存袋：上にジッパーの二重線、霜の点
            let bag = Path(roundedRect: r(0.17, 0.14, 0.66, 0.74), cornerRadius: size.width * 0.08)
            context.fill(bag, with: .color(Palette.card))
            context.fill(Path(roundedRect: r(0.22, 0.44, 0.56, 0.39), cornerRadius: size.width * 0.06), with: .color(food.opacity(0.5)))
            for y in [0.24, 0.29] as [CGFloat] {
                var zip = Path()
                zip.move(to: p(0.17, y))
                zip.addLine(to: p(0.83, y))
                context.stroke(zip, with: .color(outline), style: StrokeStyle(lineWidth: lineWidth * 0.8))
            }
            context.stroke(bag, with: .color(outline), style: stroke)
            for (x, y) in [(0.3, 0.52), (0.62, 0.6), (0.44, 0.74), (0.7, 0.78)] as [(CGFloat, CGFloat)] {
                context.fill(Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: lineWidth * 1.6, height: lineWidth * 1.6)),
                             with: .color(.white.opacity(0.9)))
            }
            center = p(0.5, 0.63)
            scale = 0.75
        }
        drawTopping(at: center, scale: scale, in: &context)
    }

    /// 品ごとの具（切り身・つくね・そぼろ・卵・葉物・細切り・丸い野菜・肉のかたまり）
    func drawTopping(at c: CGPoint, scale: CGFloat, in context: inout GraphicsContext) {
        let u = size.width / 40 * scale
        let edge = GraphicsContext.Shading.color(Palette.skyDeep.opacity(0.35))
        let thin = StrokeStyle(lineWidth: max(0.5, 0.6 * u))
        func at(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: c.x + dx * u, y: c.y + dy * u) }
        func circle(_ dx: CGFloat, _ dy: CGFloat, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: c.x + (dx - radius) * u, y: c.y + (dy - radius) * u, width: radius * 2 * u, height: radius * 2 * u))
        }
        switch topping {
        case .chunks:
            for (dx, dy) in [(-6.5, 0.0), (0.0, -3.5), (5.5, 1.0)] as [(CGFloat, CGFloat)] {
                let piece = Path(roundedRect: CGRect(x: c.x + (dx - 3.5) * u, y: c.y + (dy - 3) * u, width: 7 * u, height: 6 * u), cornerRadius: 2 * u)
                context.fill(piece, with: .color(Palette.foodMeat))
                context.stroke(piece, with: edge, style: thin)
            }
        case .fillet:
            let fish = Path(roundedRect: CGRect(x: c.x - 10 * u, y: c.y - 4 * u, width: 20 * u, height: 8 * u), cornerRadius: 4 * u)
            context.fill(fish, with: .color(Palette.foodMeat))
            context.stroke(fish, with: edge, style: thin)
            for dx in [-4.0, 0.0, 4.0] as [CGFloat] {
                var line = Path()
                line.move(to: at(dx - 1.5, -2.5))
                line.addLine(to: at(dx + 1.5, 2.5))
                context.stroke(line, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1.1 * u, lineCap: .round))
            }
        case .balls:
            for (dx, dy) in [(-5.5, 0.5), (0.0, -3.0), (5.5, 0.5)] as [(CGFloat, CGFloat)] {
                context.fill(circle(dx, dy, 3.8), with: .color(Palette.foodMeat))
                context.stroke(circle(dx, dy, 3.8), with: edge, style: thin)
                context.fill(circle(dx - 1.2, dy - 1.2, 1), with: .color(.white.opacity(0.7)))
            }
        case .mince:
            let dots: [(CGFloat, CGFloat)] = [(-7, 0), (-4, -3), (-1, 1), (2, -4), (5, -1), (7, 2), (-3, 3), (3, 3), (0, -1.5)]
            for (i, (dx, dy)) in dots.enumerated() {
                context.fill(circle(dx, dy, 1.6), with: .color(i % 3 == 0 ? Palette.foodEgg : Palette.foodMeat))
            }
        case .eggs:
            for (dx, dy) in [(-4.5, 0.5), (4.5, -1.0)] as [(CGFloat, CGFloat)] {
                let white = Path(ellipseIn: CGRect(x: c.x + (dx - 5) * u, y: c.y + (dy - 4) * u, width: 10 * u, height: 8 * u))
                context.fill(white, with: .color(.white))
                context.stroke(white, with: edge, style: thin)
                context.fill(circle(dx, dy, 2.4), with: .color(Palette.foodEgg))
            }
        case .leaves:
            for (dx, dy, flip) in [(-5.0, 1.0, 1.0), (0.0, -2.0, -1.0), (5.0, 1.0, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
                var leaf = Path()
                leaf.move(to: at(dx - 4, dy + 2 * flip))
                leaf.addQuadCurve(to: at(dx + 4, dy - 2 * flip), control: at(dx - 1, dy - 4 * flip))
                leaf.addQuadCurve(to: at(dx - 4, dy + 2 * flip), control: at(dx + 1, dy + 3 * flip))
                context.fill(leaf, with: .color(Palette.foodVeg))
                context.stroke(leaf, with: edge, style: thin)
            }
        case .sticks:
            let sticks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(-8, 2, -2, -3), (-4, 3, 3, -2), (0, 2, 7, -3), (-6, -1, 1, -5), (2, 3, 8, 0)]
            for (i, (x1, y1, x2, y2)) in sticks.enumerated() {
                var stick = Path()
                stick.move(to: at(x1, y1))
                stick.addLine(to: at(x2, y2))
                context.stroke(stick, with: .color(i % 2 == 0 ? Palette.foodEgg : (tone == .meat ? Palette.foodMeat : Palette.foodVeg)),
                               style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
            }
        case .rounds:
            let fill = tone == .egg ? Palette.foodEgg : (tone == .meat ? Palette.foodMeat : Palette.foodVeg)
            for (dx, dy, radius) in [(-5.5, 1.0, 3.6), (0.5, -2.5, 4.2), (5.5, 1.5, 3.2)] as [(CGFloat, CGFloat, CGFloat)] {
                let piece = Path(roundedRect: CGRect(x: c.x + (dx - radius) * u, y: c.y + (dy - radius) * u, width: radius * 2 * u, height: radius * 2 * u),
                                 cornerRadius: radius * 0.7 * u)
                context.fill(piece, with: .color(fill))
                context.stroke(piece, with: edge, style: thin)
            }
        }
    }
}

// MARK: - レーン（手・コンロ・レンジ・グリル・待つ）

enum LaneKind: Hashable, Sendable {
    case hands
    case burner(Int)
    case micro
    case oven
    case wait(Int)

    var label: String {
        switch self {
        case .hands: "手"
        case .burner(let n): "コンロ\(n + 1)"
        case .micro: "レンジ"
        case .oven: "グリル"
        case .wait: "待つ"
        }
    }

    var sortKey: Int {
        switch self {
        case .hands: 0
        case .burner(let n): 10 + n
        case .micro: 20
        case .oven: 30
        case .wait(let n): 40 + n
        }
    }
}

struct Lane: Identifiable, Hashable, Sendable {
    var id: LaneKind { kind }
    let kind: LaneKind
    let steps: [PlannedStep]
}

enum TimelineLayout {
    /// タイムラインの行。手の工程は「手」の行に、道具を使う工程はその道具の行に（炒めるは両方に出る）、
    /// 道具なしで待つ工程は「待つ」の行（重ならない番号ごと）に入る。使わない行は出さない
    static func lanes(_ plan: Plan) -> [Lane] {
        var groups: [LaneKind: [PlannedStep]] = [:]
        for step in plan.steps {
            if step.step.hands { groups[.hands, default: []].append(step) }
            switch step.step.device {
            case .burner: groups[.burner(step.slot), default: []].append(step)
            case .micro: groups[.micro, default: []].append(step)
            case .oven: groups[.oven, default: []].append(step)
            case .none: if !step.step.hands { groups[.wait(step.slot), default: []].append(step) }
            }
        }
        return groups.map { Lane(kind: $0.key, steps: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.kind.sortKey < $1.kind.sortKey }
    }

    /// 目盛りの間隔（分）
    static func tick(total: Int) -> Int {
        switch total {
        case ..<31: 5
        case ..<91: 10
        default: 20
        }
    }
}

struct LaneGlyph: View {
    let kind: LaneKind
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvas in
            let w = canvas.width, h = canvas.height
            let style = StrokeStyle(lineWidth: max(1, w / 14), lineCap: .round, lineJoin: .round)
            let ink = GraphicsContext.Shading.color(Palette.skyDeep)
            switch kind {
            case .hands:
                // まな板と包丁
                let board = Path(roundedRect: CGRect(x: w * 0.08, y: h * 0.5, width: w * 0.84, height: h * 0.32), cornerRadius: w * 0.08)
                context.stroke(board, with: ink, style: style)
                var knife = Path()
                knife.move(to: CGPoint(x: w * 0.3, y: h * 0.4))
                knife.addLine(to: CGPoint(x: w * 0.78, y: h * 0.14))
                context.stroke(knife, with: ink, style: style)
            case .burner:
                // コンロの口：輪と五徳
                context.stroke(Path(ellipseIn: CGRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: h * 0.6)), with: ink, style: style)
                for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 2) {
                    var spoke = Path()
                    let c = CGPoint(x: w / 2, y: h / 2)
                    spoke.move(to: CGPoint(x: c.x + CGFloat(cos(angle)) * w * 0.32, y: c.y + CGFloat(sin(angle)) * h * 0.32))
                    spoke.addLine(to: CGPoint(x: c.x + CGFloat(cos(angle)) * w * 0.48, y: c.y + CGFloat(sin(angle)) * h * 0.48))
                    context.stroke(spoke, with: ink, style: style)
                }
            case .micro:
                // レンジ：窓とつまみ
                context.stroke(Path(roundedRect: CGRect(x: w * 0.06, y: h * 0.22, width: w * 0.88, height: h * 0.58), cornerRadius: w * 0.08), with: ink, style: style)
                context.stroke(Path(roundedRect: CGRect(x: w * 0.18, y: h * 0.34, width: w * 0.46, height: h * 0.34), cornerRadius: w * 0.04), with: ink, style: style)
                context.fill(Path(ellipseIn: CGRect(x: w * 0.72, y: h * 0.42, width: w * 0.12, height: h * 0.12)), with: ink)
            case .oven:
                // グリル：網
                context.stroke(Path(roundedRect: CGRect(x: w * 0.08, y: h * 0.24, width: w * 0.84, height: h * 0.54), cornerRadius: w * 0.08), with: ink, style: style)
                for y in [0.42, 0.6] as [CGFloat] {
                    var bar = Path()
                    bar.move(to: CGPoint(x: w * 0.2, y: h * y))
                    bar.addLine(to: CGPoint(x: w * 0.8, y: h * y))
                    context.stroke(bar, with: ink, style: style)
                }
            case .wait:
                // 砂時計
                var glass = Path()
                glass.move(to: CGPoint(x: w * 0.24, y: h * 0.12))
                glass.addLine(to: CGPoint(x: w * 0.76, y: h * 0.12))
                glass.addLine(to: CGPoint(x: w * 0.24, y: h * 0.88))
                glass.addLine(to: CGPoint(x: w * 0.76, y: h * 0.88))
                glass.closeSubpath()
                context.stroke(glass, with: ink, style: style)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - タイムライン（帯の中には番号だけ。説明はルートの一覧に出し、文字が重ならない）

struct TimelineChart: View {
    let plan: Plan
    /// 品の並び（番号を振る順）
    let order: [String]
    var done: Set<String> = []
    var current: String?
    /// 今の時刻（分）。ラン中だけ
    var nowMinutes: Double?
    var rowHeight: CGFloat = 26

    private var lanes: [Lane] { TimelineLayout.lanes(plan) }
    private let header: CGFloat = 50
    private let axis: CGFloat = 18

    var height: CGFloat { CGFloat(lanes.count) * (rowHeight + 6) + axis }

    var body: some View {
        GeometryReader { geo in
            let total = max(plan.totalMinutes, 1)
            let width = max(1, geo.size.width - header)
            let scale = width / CGFloat(total)
            ZStack(alignment: .topLeading) {
                // 目盛り
                let tick = TimelineLayout.tick(total: total)
                ForEach(Array(stride(from: 0, through: total, by: tick)), id: \.self) { minute in
                    let x = header + CGFloat(minute) * scale
                    Rectangle().fill(Palette.line).frame(width: 0.6, height: height - axis + 2)
                        .offset(x: x, y: axis - 2)
                    Text("\(minute)")
                        .font(.system(size: 10, design: .serif)).monospacedDigit()
                        .foregroundStyle(Palette.sub)
                        .fixedSize()
                        .frame(width: 28, alignment: minute == 0 ? .leading : .center)
                        .offset(x: minute == 0 ? x : x - 14, y: 0)
                }
                ForEach(Array(lanes.enumerated()), id: \.element.id) { row, lane in
                    let y = axis + CGFloat(row) * (rowHeight + 6)
                    HStack(spacing: 4) {
                        LaneGlyph(kind: lane.kind, size: 14)
                        Text(lane.kind.label).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.sub)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(width: header - 4, height: rowHeight, alignment: .leading)
                    .offset(x: 0, y: y)
                    ForEach(lane.steps) { step in
                        block(step, scale: scale)
                            .offset(x: header + CGFloat(step.start) * scale + 1, y: y)
                    }
                }
                if let nowMinutes {
                    Rectangle().fill(Palette.peach).frame(width: 2, height: height - axis + 4)
                        .offset(x: header + CGFloat(min(nowMinutes, Double(total))) * scale - 1, y: axis - 4)
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("段取りのタイムライン。目安 \(plan.totalMinutes) 分")
    }

    private func block(_ step: PlannedStep, scale: CGFloat) -> some View {
        let width = max(3, CGFloat(step.step.minutes) * scale - 2)
        let isDone = done.contains(step.id)
        let isCurrent = current == step.id
        let number = (order.firstIndex(of: step.recipeID) ?? 0) + 1
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(step.step.hands ? Palette.sky : Palette.skySoft)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isCurrent ? Palette.peach : Palette.sky.opacity(step.step.hands ? 0 : 0.9),
                            lineWidth: isCurrent ? 2 : 0.8)
            }
            .overlay {
                if width >= 16 {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(step.step.hands ? Color.white : Palette.skyDeep)
                }
            }
            .frame(width: width, height: rowHeight)
            .opacity(isDone ? 0.35 : 1)
    }
}

// MARK: - 小さな部品

/// ランク（S〜D）の丸い印
struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Palette.rank(rank).opacity(0.28))
            Circle().stroke(Palette.rank(rank), lineWidth: max(1.2, size / 28))
            Text(rank.rawValue)
                .font(.system(size: size * 0.5, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("ランク \(rank.rawValue)、\(rank.title)")
    }
}

/// 自己ベストの小さな札
struct PBTag: View {
    var text = "自己ベスト"
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(Palette.peachInk)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Palette.peachSoft))
            .fixedSize()
    }
}

/// 大きな数字と単位・説明
struct BigNumber: View {
    let value: String
    var unit: String = ""
    let caption: String
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Typo.number(size)).kerning(-size * 0.04).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                if !unit.isEmpty { Text(unit).font(.system(.caption, design: .serif)) }
            }
            .foregroundStyle(Palette.ink)
            Text(caption).font(Typo.label).kerning(0.4).foregroundStyle(Palette.sub).lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 品の番号つきの札（器の絵・番号・名前）
struct DishChip: View {
    let recipe: Recipe
    let number: Int
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            DishIcon(recipe: recipe, size: 26)
            Text("\(number)").font(.system(size: 12, weight: .semibold, design: .serif)).foregroundStyle(Palette.skyDeep)
            Text(recipe.name).font(.system(.footnote, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.sub)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("\(recipe.name)を外す")
            }
        }
        .padding(.leading, 6).padding(.trailing, onRemove == nil ? 12 : 4).padding(.vertical, 4)
        .background(Capsule().fill(Palette.card))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 0.8))
    }
}

/// 見出し（小さな英字のラベル＋セリフの見出し）
struct SectionTitle: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased()).smallLabel()
            Text(title).font(Typo.serif(.title3)).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 空の状態：何をすれば価値が出るかの一文と、次の一歩
struct EmptyNote: View {
    let title: String
    let message: String
    let action: String
    let perform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
            Text(message).font(Typo.small).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform).buttonStyle(LineButtonStyle()).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}
