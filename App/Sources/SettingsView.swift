import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Heading(kicker: "Settings", title: "設定")
                group("台所") {
                    HStack {
                        Text("コンロの口の数").font(Typo.body).foregroundStyle(Palette.ink)
                        Spacer()
                        Stepper(value: $model.kitchen.burners, in: 1...3) {
                            Text("\(model.kitchen.burners) 口").font(.system(.footnote, design: .serif)).monospacedDigit()
                        }
                        .fixedSize()
                    }
                    note("段取りの計算に使います。レンジとグリルは 1 台ずつとして数えます。")
                }
                group("手応え") {
                    Toggle(isOn: $model.hapticsOn) { Text("振動").font(Typo.body).foregroundStyle(Palette.ink) }
                        .tint(Palette.mintDeep)
                    note("動きは iPhone の「視差効果を減らす」に合わせて止まります。")
                }
                group("Pro") {
                    HStack {
                        Text(model.isPro ? "Pro をお使いです" : "無料でお使いです").font(Typo.body).foregroundStyle(Palette.ink)
                        Spacer()
                        Button(model.isPro ? "内容を見る" : "Pro について") { model.offerPaywall(.menu) }
                            .buttonStyle(LineButtonStyle())
                    }
                    Button("購入を復元") { Task { await model.purchases.restore() } }
                        .font(Typo.small).foregroundStyle(Palette.mintDeep).frame(minHeight: 44)
                }
                group("使い方") {
                    Button("使い方をもう一度見る") { model.onboardingDone = false }
                        .font(Typo.body).foregroundStyle(Palette.mintDeep).frame(minHeight: 44)
                    Button("見本の容器を冷蔵庫に入れる") { model.putSamples() }
                        .font(Typo.body).foregroundStyle(Palette.mintDeep).frame(minHeight: 44)
                    Button("記録をすべて消す") { confirmReset = true }
                        .font(Typo.body).foregroundStyle(Palette.sub).frame(minHeight: 44)
                }
                group("プライバシー") {
                    note("記録はこの iPhone の中だけに保存します。登録・通信・広告・解析はありません。アプリを削除すると記録も消えます。")
                    note("日持ちと時間はめやすです。においや見た目がおかしいときは食べないでください。")
                }
                Text("段取り帖 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .smallLabel()
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .confirmationDialog("記録をすべて消しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("消す", role: .destructive) { model.resetAll() }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("冷蔵庫の容器・食べきりの記録・段取りが消えます。Pro の購入は消えません。")
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).smallLabel()
            VStack(alignment: .leading, spacing: 6) { content() }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Palette.paper))
                .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Typo.small).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
    }
}
