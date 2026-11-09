import SwiftUI

/// 設定：Pro・台所・手応え・使い方・データ。素のリストにせず、ほかの画面と同じ面で組む
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var askReset = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                proCard
                group("台所") {
                    row(glyph: .burner(0), title: "コンロの口", detail: "段取りの計算に使います") {
                        Stepper("\(model.kitchen.burners) 口", value: $model.kitchen.burners, in: 1...3)
                            .font(.system(.subheadline, design: .serif)).monospacedDigit().fixedSize()
                    }
                    divider
                    row(glyph: .micro, title: "レンジ・グリル", detail: "どちらも 1 台として計算します") { EmptyView() }
                }
                group("手応え") {
                    row(glyph: .hands, title: "振動", detail: "工程を押したとき・待つ工程が終わったとき") {
                        Toggle("振動", isOn: $model.hapticsOn).labelsHidden().tint(Palette.skyDeep)
                    }
                }
                group("使い方") {
                    Button {
                        dismiss()
                        model.onboardingDone = false
                    } label: {
                        row(glyph: .wait(0), title: "はじめの案内をもう一度見る", detail: "3 ページ") {
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.sub)
                        }
                    }
                    .buttonStyle(.plain)
                }
                group("データ") {
                    Text("記録はこの iPhone の中だけに保存します。登録・通信・広告・解析はありません。時間と日持ちはめやすです。")
                        .font(Typo.small).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                    divider
                    Button("すべての記録を消す", role: .destructive) { askReset = true }
                        .font(.system(.subheadline)).foregroundStyle(Palette.peachInk).frame(minHeight: 44)
                }
                Text("段取りラン \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(Typo.label).foregroundStyle(Palette.sub).frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
        }
        .confirmationDialog("ランの記録・冷蔵庫・コースを全部消します。元に戻せません。", isPresented: $askReset, titleVisibility: .visible) {
            Button("消す", role: .destructive) { model.resetAll() }
        }
    }

    private var proCard: some View {
        Button {
            dismiss()
            model.offerPaywallSoon(.menu)
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: -12) {
                    DishIcon(vessel: .bento, tone: .egg, topping: .eggs, size: 40)
                    DishIcon(vessel: .bag, tone: .meat, topping: .chunks, size: 40)
                    DishIcon(vessel: .cup, tone: .veg, topping: .leaves, size: 40)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isPro ? "Pro をお使いです" : "段取りラン Pro").font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
                    Text(model.isPro ? "ゴースト・全レシピ・全部の記録" : "自己ベストのゴースト・全 50 品・全部の記録")
                        .font(.system(size: 12)).foregroundStyle(Palette.sub)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.sub)
            }
            .panel(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View { Rectangle().fill(Palette.line).frame(height: 0.6) }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).smallLabel().padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) { content() }
                .panel(padding: 14)
        }
    }

    private func row<Trailing: View>(glyph: LaneKind, title: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            LaneGlyph(kind: glyph, size: 22)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.skySoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(Palette.sub)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
