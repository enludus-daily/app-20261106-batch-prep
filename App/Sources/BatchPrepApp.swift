import SwiftUI

@main
struct BatchPrepApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // 冷蔵庫の白と紙のラベルの世界観を保つため、ライトに固定する（StudyReel と同じ判断）
                .preferredColorScheme(.light)
                .tint(Palette.mintDeep)
                .task { await model.purchases.load() }
        }
    }
}

/// 3 つの場所（冷蔵庫・段取り・レシピ帳）と設定。iPhone Duo の内側では TabView がサイドバーにもなる
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboardingDone {
                TabView(selection: $model.tab) {
                    Tab("冷蔵庫", systemImage: "refrigerator", value: AppTab.fridge) { FridgeView() }
                    Tab("段取り", systemImage: "list.bullet.rectangle", value: AppTab.plan) { PlanView() }
                    Tab("レシピ帳", systemImage: "book", value: AppTab.recipes) {
                        NavigationStack { RecipeBookView() }
                    }
                    Tab("設定", systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
                }
                .tabViewStyle(.sidebarAdaptable)
                .transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView().presentationBackground(Palette.ground)
        }
        .onAppear {
            if model.screenshotScene == "settings" { model.tab = .settings }
        }
    }
}
