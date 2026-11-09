import SwiftUI

@main
struct BatchPrepApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // 淡い水色と白の世界観を保つため、ライトに固定する（StudyReel と同じ判断）
                .preferredColorScheme(.light)
                .tint(Palette.skyDeep)
                .task { await model.purchases.load() }
        }
    }
}

/// iOS 26 の標準のタブ（下に浮いたガラスのタブバー）。ラン・冷蔵庫・レシピの 3 つ
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Palette.ground.ignoresSafeArea()
            if model.onboardingDone {
                TabView(selection: $model.tab) {
                    Tab("ラン", systemImage: "stopwatch", value: AppTab.run) {
                        NavigationStack { RunHomeView() }
                    }
                    Tab("冷蔵庫", systemImage: "refrigerator", value: AppTab.fridge) {
                        NavigationStack { FridgeView() }
                    }
                    Tab("レシピ", systemImage: "fork.knife", value: AppTab.recipes) {
                        NavigationStack { RecipeBookView() }
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $model.showRun) {
            RunView()
                .environment(model)
        }
        .sheet(item: $model.result, onDismiss: { model.closeResult() }) { record in
            ResultView(record: record)
                .environment(model)
                .presentationBackground(Palette.ground)
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView()
                .environment(model)
                .presentationBackground(Palette.ground)
        }
    }
}
