import SwiftUI

// 題材の現物を部品にする：保存容器・マスキングテープのラベル・冷蔵庫の棚・方眼のメモ。

/// 両端がギザギザのマスキングテープ
struct TapeShape: Shape {
    var teeth = 4
    var depth: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = rect.height / CGFloat(teeth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        for i in 0..<teeth {
            let y = rect.minY + CGFloat(i) * step
            p.addLine(to: CGPoint(x: rect.maxX - depth, y: y + step / 2))
            p.addLine(to: CGPoint(x: rect.maxX, y: y + step))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in (0..<teeth).reversed() {
            let y = rect.minY + CGFloat(i) * step
            p.addLine(to: CGPoint(x: rect.minX + depth, y: y + step / 2))
            p.addLine(to: CGPoint(x: rect.minX, y: y))
        }
        p.closeSubpath()
        return p
    }
}

/// 容器に貼るラベル（品名と、あと何日）
struct TapeLabel: View {
    let title: String
    var detail: String?
    var tilt: Double = -3

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(.caption, design: .serif, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail).font(.system(.caption2)).monospacedDigit()
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(TapeShape().fill(Palette.tape.opacity(0.85)))
        .rotationEffect(.degrees(tilt))
    }
}

/// 保存容器。中身の高さが残りの食数、ふたの色が状態
struct ContainerView: View {
    let item: FridgeItem
    let freshness: Freshness
    var selected = false

    private var fill: Double { item.portions == 0 ? 0 : Double(item.left) / Double(item.portions) }
    /// 容器ごとに少しだけ傾きを変える（id から決めるので毎回同じ）
    private var tilt: Double { Double(Int(item.id.uuid.0) % 5 - 2) }

    var body: some View {
        VStack(spacing: 0) {
            // ふた
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(item.frozen ? Palette.mintSoft : Palette.mint.opacity(0.55))
                .frame(height: 9)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Palette.mintDeep.opacity(0.25), lineWidth: 0.6))
                .padding(.horizontal, -3)
            // 本体（半透明の容器と、中身）
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.paper.opacity(0.9))
                GeometryReader { geo in
                    VStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Palette.freshness(freshness).opacity(0.55))
                            .frame(height: max(4, (geo.size.height - 6) * fill))
                            .padding(3)
                    }
                }
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
                // 目盛り（何食分か）
                VStack(spacing: 0) {
                    ForEach(0..<max(1, item.portions), id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle().fill(Palette.line).frame(width: 6, height: 0.6)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
            }
            .frame(height: 54)
        }
        .overlay(alignment: .center) {
            TapeLabel(title: item.name, detail: item.frozen ? "冷凍" : freshness.label, tilt: tilt)
                .offset(y: 8)
                .padding(.horizontal, -4)
        }
        .scaleEffect(selected ? 1.06 : 1)
        .offset(y: selected ? -4 : 0)
        .modifier(SelectedShadow(on: selected))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)、\(item.frozen ? "冷凍" : freshness.label)、残り\(item.left)食")
    }
}

private struct SelectedShadow: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.liftedShadow() } else { content }
    }
}

/// 冷蔵庫の棚（ガラスの棚板の線）
struct ShelfLine: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.line).frame(height: 1)
            Rectangle().fill(Palette.mintSoft.opacity(0.8)).frame(height: 5)
        }
        .accessibilityHidden(true)
    }
}

/// 方眼のメモ（20pt 間隔・線 0.6、下へ薄く）
struct GridPaper: View {
    var spacing: CGFloat = 20
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(Palette.line), lineWidth: 0.6)
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}

/// 見出し（セリフ・字間を詰める）と、小さな英字のラベル
struct Heading: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased()).smallLabel()
            Text(title).font(Typo.serif(.title2)).kerning(-0.5).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 大きな数字（セリフ・字間を詰める）と、その下の小さな説明
struct BigNumber: View {
    let value: String
    let unit: String
    let caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .kerning(-2)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit).font(.system(.footnote, design: .serif))
            }
            .foregroundStyle(Palette.ink)
            Text(caption).smallLabel()
        }
        .accessibilityElement(children: .combine)
    }
}

/// 空の画面：何をすれば価値が出るかの一文と、次の一歩
struct EmptyNote: View {
    let title: String
    let message: String
    let action: String
    let perform: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            TapeLabel(title: title, tilt: -4)
            Text(message)
                .font(Typo.body)
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform).buttonStyle(LineButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
