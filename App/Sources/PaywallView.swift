import StoreKit
import SwiftUI

/// 課金の画面。はじめてのランを走り終えた直後に 1 回だけ、または Pro の物に触れたとき・設定から
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
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("段取りラン PRO").font(Typo.label).kerning(0.8).foregroundStyle(Palette.peachInk)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.peachSoft))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.sub).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                Text(model.paywallReason.headline)
                    .font(Typo.serif(.title)).kerning(-0.5).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("一度買えば、ずっと使えます（買い切り）。ご家族とも共有できます。")
                    .font(Typo.body).foregroundStyle(Palette.sub)

                feature(title: "自己ベストのゴーストと走る",
                        detail: "ラン中に「自己ベストより −0:20」。同じコースを走るたびに、過去の自分との差が工程ごとに出ます。") {
                    HStack(spacing: 6) {
                        Circle().stroke(Palette.peach, style: StrokeStyle(lineWidth: 1.4, dash: [2, 2])).frame(width: 14, height: 14)
                        Text("−0:20").font(.system(size: 18, design: .serif)).monospacedDigit().foregroundStyle(Palette.skyDeep)
                    }
                }
                feature(title: "レシピ \(RecipeBook.all.count) 品と組み合わせ 8 つ",
                        detail: "無料の \(RecipeBook.all.filter { !$0.isPro }.count) 品に、お弁当・冷凍の素・汁の素・漬け・週末のごちそうの \(RecipeBook.all.filter(\.isPro).count) 品。1 回のランに 8 品まで（無料は 3 品）。") {
                    HStack(spacing: -10) {
                        DishIcon(vessel: .bento, tone: .egg, garnish: .leaf, size: 30)
                        DishIcon(vessel: .bag, tone: .meat, garnish: .dots, size: 30)
                        DishIcon(vessel: .cup, tone: .veg, garnish: .slices, size: 30)
                    }
                }
                feature(title: "全部のランとスプリットを見返す",
                        detail: "無料は新しい \(ProRules.freeHistory) 本まで。どの工程で縮んだかを、1 年前のランとも比べられます。") {
                    RankBadge(rank: .s, size: 34)
                }

                Text("お試し：はじめてのランは 8 品まで、ゴーストは 1 回だけ無料で使えます。")
                    .font(.system(size: 12)).foregroundStyle(Palette.skyDeep)

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
                .font(Typo.small).foregroundStyle(Palette.skyDeep).frame(minHeight: 44)

                if let message {
                    Text(message).font(Typo.small).foregroundStyle(Palette.sub)
                }
                Text("お支払いは Apple ID に請求されます。買い切り（自動更新なし）です。記録はこの iPhone の中だけに保存し、外に送りません。")
                    .font(Typo.label).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .sensoryFeedback(trigger: boughtTick) { _, _ in model.hapticsOn ? .success : nil }
        .task {
            if store.loadState == .idle || store.loadState == .unavailable { await store.load() }
        }
    }

    private func feature<Art: View>(title: String, detail: String, @ViewBuilder art: () -> Art) -> some View {
        HStack(alignment: .center, spacing: 14) {
            art().frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .panel(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func priceLine(_ price: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(price).font(Typo.number(36)).kerning(-1.5).foregroundStyle(Palette.ink)
            Text("買い切り・ずっと").font(Typo.small).foregroundStyle(Palette.sub)
        }
    }

    @ViewBuilder
    private var priceBlock: some View {
        if model.isPro {
            Text("Pro をお使いいただいています。ありがとうございます。")
                .font(Typo.serif(.headline)).foregroundStyle(Palette.skyDeep)
            Button("閉じる") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        } else if let product {
            VStack(alignment: .leading, spacing: 10) {
                priceLine(product.displayPrice)
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
                priceLine("¥800")
                Button("Pro にする") {}.buttonStyle(PrimaryButtonStyle())
            }
        } else if store.loadState == .loading || store.loadState == .idle {
            HStack(spacing: 10) {
                ProgressView()
                Text("値段を読み込んでいます").font(Typo.small).foregroundStyle(Palette.sub)
            }
            .frame(minHeight: 54)
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
