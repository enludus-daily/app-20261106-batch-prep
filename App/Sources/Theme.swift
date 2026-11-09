import SwiftUI

// 色・書体・形を 1 か所で決める（app-quality-bar の look.md §0：StudyReel のトーン）。
// 色は sky の 1 系統。差し色の peach は「自己ベスト」「今の工程」の小さな印だけ。
// 明度：sky 0.75・peach 0.80・skySoft 0.92。deep は白文字のボタンと小さな文字だけ（彩度 0.39）。
enum Palette {
    static let sky = Color(hex: 0x9EC3E2)       // 主な色（手の帯・グラフ・進み具合）
    static let skySoft = Color(hex: 0xE1EDF6)   // 待つ帯・選択中の地
    static let skyDeep = Color(hex: 0x5E8DB8)   // 白文字のボタン・小さな強調
    static let ground = Color(hex: 0xF3F6F9)    // 地（ほぼ白、わずかに青）
    static let card = Color(hex: 0xFCFDFE)      // 浮いた面
    static let ink = Color(hex: 0x2E3A46)       // 文字（真っ黒にしない）
    static let sub = Color(hex: 0x8E9AA6)       // 補助の文字
    static let line = Color(hex: 0xE3E9EF)      // 細い線
    static let peach = Color(hex: 0xF4BBA4)     // 差し色（自己ベスト・今）
    static let peachSoft = Color(hex: 0xFBE6DD) // 差し色の淡い地
    static let peachInk = Color(hex: 0xA8664C)  // 差し色の上の小さな文字（明度 0.48・彩度 0.38）

    // 器の中身（料理の色）。小さな器の絵の中だけに使う淡い色（明度 0.74〜0.80）
    static let foodMeat = Color(hex: 0xD7C1AA)  // 肉・魚（milktea）
    static let foodVeg = Color(hex: 0xBFD0A9)   // 野菜（matcha）
    static let foodEgg = Color(hex: 0xF1D98A)   // 卵・豆（butter）

    /// 食べきりのめやすの段階（1 系統の中で濃さを変え、今日・すぎたにだけ peach）
    static func freshness(_ f: Freshness) -> Color {
        switch f {
        case .fresh: sky
        case .soon: sky.opacity(0.6)
        case .today: peach
        case .over: sub.opacity(0.45)
        }
    }

    /// ランクの色（S と A は peach の差し色、ほかは sky の段階）
    static func rank(_ r: Rank) -> Color {
        switch r {
        case .s: peach
        case .a: sky
        case .b: sky.opacity(0.7)
        case .c, .d: sub.opacity(0.5)
        }
    }

    /// 目安との差。早ければ sky の濃い色、遅ければ peach の文字色
    static func delta(_ seconds: Int) -> Color { seconds <= 0 ? skyDeep : peachInk }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// 2 書体：大きな数字と見出しはセリフ、本文はサンセリフ。Dynamic Type に追従する
enum Typo {
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
    /// 大きな数字（タイム）。字間は呼ぶ側で詰める
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
    static let body = Font.system(.subheadline)
    static let small = Font.system(.footnote)
    static let label = Font.system(.caption2, weight: .medium)
}

enum Radius {
    static let tag: CGFloat = 6
    static let control: CGFloat = 14
    static let panel: CGFloat = 20
    static let sheet: CGFloat = 26
}

extension View {
    /// 普段の弱い影
    func softShadow() -> some View { shadow(color: Palette.ink.opacity(0.06), radius: 12, x: 0, y: 4) }
    /// 小さなラベルは字間を開ける
    func smallLabel() -> some View { font(Typo.label).kerning(0.6).foregroundStyle(Palette.sub) }
    /// 浮いた面（白に近い地・角丸 20・細い線・弱い影）
    func panel(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 0.8))
            .softShadow()
    }
}

/// 白文字を載せる主なボタン（deep の地。グラデーションは使わない）
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(enabled ? Palette.skyDeep : Palette.sub.opacity(0.5)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 線だけのボタン
struct LineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(Palette.skyDeep)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(Capsule().stroke(Palette.skyDeep.opacity(0.4), lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 時間の書き方（42:18、1:02:05）
enum Clock {
    static func text(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// 差（−1:36 / +0:45）
    static func delta(_ seconds: Int) -> String {
        (seconds <= 0 ? "−" : "+") + text(abs(seconds))
    }
}
