import StoreKit
import SwiftUI

/// 課金の画面。価値を感じた直後（はじめての段取りのあと）か、Pro の物に触れたときだけ出す
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var message: String?
    @State private var boughtTick = 0

    private var store: PurchaseStore { model.purchases }
    private var product: Product? { store.products.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.sub).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                TapeLabel(title: "段取り帖 Pro", tilt: -4)
                Text(model.paywallReason.headline)
                    .font(Typo.serif(.title)).kerning(-0.5).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("一度買えば、ずっと使えます。ご家族とも共有できます。")
                    .font(Typo.body).foregroundStyle(Palette.sub)

                VStack(spacing: 12) {
                    feature(number: "\(RecipeBook.all.filter(\.isPro).count)", unit: "品",
                            title: "レシピの束がすべて開く",
                            detail: "お弁当・冷凍の素・汁の素・漬け・週末のごちそう。組み合わせ 4 つも")
                    feature(number: "\(ProRules.proDishLimit)", unit: "品",
                            title: "1 回の段取りに 8 品まで",
                            detail: "無料は 3 品。コンロ 2 口を使いきる週末の大仕事に")
                    feature(number: "52", unit: "週",
                            title: "1 年分の食べきりカレンダー",
                            detail: "無料は 4 週。捨てずに食べきった季節が見える")
                }

                priceBlock

                Button("購入を復元") {
                    Task {
                        working = true
                        await store.restore()
                        working = false
                        message = store.entitlements.isPro ? "復元しました。" : "復元できる購入が見つかりませんでした。"
                        if store.entitlements.isPro { boughtTick += 1 }
                    }
                }
                .font(Typo.small).foregroundStyle(Palette.mintDeep).frame(minHeight: 44)

                if let message {
                    Text(message).font(Typo.small).foregroundStyle(Palette.sub)
                }
                Text("お支払いは Apple ID に請求されます。買い切り（自動更新なし）です。データはこの iPhone の中だけに保存され、外に送りません。")
                    .font(Typo.label).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(alignment: .top) { GridPaper().frame(height: 260) }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: boughtTick) { _, _ in model.hapticsOn ? .success : nil }
        .task {
            if store.loadState == .idle || store.loadState == .unavailable { await store.load() }
        }
    }

    private func feature(number: String, unit: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(number).font(.system(size: 30, design: .serif)).kerning(-1.5).monospacedDigit()
                Text(unit).font(.system(.caption, design: .serif))
            }
            .foregroundStyle(Palette.mintDeep)
            .frame(width: 66, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(Typo.small).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var priceBlock: some View {
        if model.isPro {
            Text("Pro をお使いいただいています。ありがとうございます。")
                .font(Typo.serif(.headline)).foregroundStyle(Palette.mintDeep)
            Button("閉じる") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        } else if let product {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(product.displayPrice).font(.system(size: 34, design: .serif)).kerning(-1.5).foregroundStyle(Palette.ink)
                    Text("買い切り").font(Typo.small).foregroundStyle(Palette.sub)
                }
                Button(working ? "購入しています…" : "Pro にする") {
                    Task {
                        working = true
                        let outcome = await store.purchase(product)
                        working = false
                        switch outcome {
                        case .purchased: boughtTick += 1; message = "ありがとうございます。Pro が開きました。"
                        case .pending: message = "承認を待っています。承認されると自動で開きます。"
                        case .cancelled: message = nil
                        case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください。"
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: !working))
                .disabled(working)
            }
        } else if model.screenshotScene != nil {
            // CI のスクリーンショット（審査用の画像）だけ：シミュレータでは商品を読めないので、docs/products.json の値段を見せる
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("¥480").font(.system(size: 34, design: .serif)).kerning(-1.5).foregroundStyle(Palette.ink)
                    Text("買い切り").font(Typo.small).foregroundStyle(Palette.sub)
                }
                Button("Pro にする") {}.buttonStyle(PrimaryButtonStyle())
            }
        } else if store.loadState == .loading || store.loadState == .idle {
            HStack(spacing: 10) {
                ProgressView()
                Text("値段を読み込んでいます").font(Typo.small).foregroundStyle(Palette.sub)
            }
            .frame(minHeight: 52)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("いまは購入できません").font(Typo.serif(.headline)).foregroundStyle(Palette.ink)
                Text("通信のよいところで、もう一度開いてください。無料の機能はそのまま使えます。")
                    .font(Typo.small).foregroundStyle(Palette.sub)
                Button("もう一度読み込む") { Task { await store.load() } }.buttonStyle(LineButtonStyle())
            }
        }
    }
}
