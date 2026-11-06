import SwiftUI

// 色・書体・形を 1 か所で決める（app-quality-bar の look.md）。
// 色は mint の 1 系統。台所の白い冷蔵庫と、保存容器に貼るマスキングテープ（butter）。
// 明度：mint 0.76・tape 0.79・peach 0.80（淡い色）。deep は白文字を載せるボタンと小さな文字だけ（彩度 0.29）。
enum Palette {
    static let mint = Color(hex: 0xA8DCCB)      // 主な色（帯・容器の中身・グラフ）
    static let mintSoft = Color(hex: 0xE3F3EE)  // 選択中・札の地
    static let mintDeep = Color(hex: 0x4F8F7C)  // 白文字のボタン・小さな強調
    static let paper = Color(hex: 0xFBFCFC)     // 冷蔵庫の内側・紙
    static let ground = Color(hex: 0xF1F6F4)    // 地（ほぼ白、わずかに緑）
    static let ink = Color(hex: 0x2E3A3F)       // 文字（真っ黒にしない）
    static let sub = Color(hex: 0x8A9A97)       // 補助の文字
    static let line = Color(hex: 0xDDE7E3)      // 細い線・方眼
    static let tape = Color(hex: 0xF3DFA2)      // マスキングテープ（飾り。1 画面に数枚まで）
    static let peach = Color(hex: 0xF4BBA4)     // 今日まで・すぎた の小さな印だけ
    static let fog = Color(hex: 0xCFC8C2)       // すぎた容器の中身

    /// 食べきりのめやすの段階（1 系統の中で濃さを変え、今日・すぎたにだけ peach を小さく使う）
    static func freshness(_ f: Freshness) -> Color {
        switch f {
        case .fresh: mint
        case .soon: mint.opacity(0.75)
        case .today: peach
        case .over: fog
        }
    }

    /// カレンダーのマスの濃さ（0〜4）
    static func heat(_ level: Int) -> Color {
        level == 0 ? line.opacity(0.7) : mint.opacity([0, 0.35, 0.6, 0.85, 1][min(level, 4)])
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// 2 書体：見出しと大きな数字はセリフ、本文はサンセリフ。Dynamic Type に追従する
enum Typo {
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
    static let body = Font.system(.subheadline)
    static let small = Font.system(.footnote)
    static let label = Font.system(.caption2, weight: .medium)
}

enum Radius {
    static let tag: CGFloat = 6
    static let control: CGFloat = 12
    static let panel: CGFloat = 14
    static let sheet: CGFloat = 18
}

extension View {
    /// 普段の弱い影
    func softShadow() -> some View { shadow(color: Palette.ink.opacity(0.07), radius: 10, x: 0, y: 4) }
    /// 浮いた物（容器を持ち上げたとき）
    func liftedShadow() -> some View { shadow(color: Palette.ink.opacity(0.16), radius: 8, x: 0, y: 6) }
    /// 小さなラベルは字間を開ける
    func smallLabel() -> some View { font(Typo.label).kerning(0.6).foregroundStyle(Palette.sub) }
}

/// 白文字を載せる主なボタン（deep の地。グラデーションは使わない）
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(enabled ? Palette.mintDeep : Palette.sub.opacity(0.5)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 線だけのボタン
struct LineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(Palette.mintDeep)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Palette.mintDeep.opacity(0.45), lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
