import Foundation
import Observation
import SwiftUI

/// 画面が見る状態。保存は UserDefaults の JSON 1 つ（端末の中だけ）。
@MainActor
@Observable
final class AppModel {
    var ledger = FridgeLedger() { didSet { save() } }
    /// 段取りに選んだ品（選んだ順）
    var selectedIDs: [String] = [] { didSet { save() } }
    var kitchen = KitchenSetup() { didSet { save() } }
    var plansCompleted = 0 { didSet { save() } }
    var shoppingChecked: Set<String> = [] { didSet { save() } }
    var hapticsOn = true { didSet { save() } }
    var onboardingDone = false { didSet { save() } }
    var paywallShownDay: String? { didSet { save() } }
    /// 調理中の工程（チェックした工程の id）
    var cookedStepIDs: Set<String> = []

    var tab: AppTab = .fridge
    var showPaywall = false
    var pendingPaywall = false
    var paywallReason: PaywallReason = .menu

    let purchases: PurchaseStore
    let screenshotScene: String?
    @ObservationIgnored private var loading = true
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let calendar = Calendar.current

    static let storageKey = "batchprep.state.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.004"
        let pro = ProductID.pro(bundleID: bundleID)
        purchases = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        let scene = defaults.string(forKey: "screenshotScene")
        screenshotScene = (scene?.isEmpty ?? true) ? nil : scene
        if screenshotScene != nil {
            loadScreenshotState()
        } else if let data = defaults.data(forKey: Self.storageKey),
                  let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            ledger = saved.ledger
            selectedIDs = saved.selectedIDs
            kitchen = saved.kitchen
            plansCompleted = saved.plansCompleted
            shoppingChecked = saved.shoppingChecked
            hapticsOn = saved.hapticsOn
            onboardingDone = saved.onboardingDone
            paywallShownDay = saved.paywallShownDay
        } else {
            putSamples()
        }
        loading = false
    }

    // MARK: - 権利

    var isPro: Bool { purchases.entitlements.isPro || screenshotScene == "pro" }
    var dishLimit: Int { ProRules.dishLimit(isPro: isPro, plansCompleted: plansCompleted) }
    var today: Date { Date() }

    // MARK: - 段取り

    var selectedRecipes: [Recipe] { selectedIDs.compactMap(RecipeBook.recipe) }
    var plan: Plan { Scheduler.plan(selectedRecipes, kitchen: kitchen) }

    enum ToggleResult { case added, removed, locked, full }

    @discardableResult
    func toggle(_ recipe: Recipe) -> ToggleResult {
        if let index = selectedIDs.firstIndex(of: recipe.id) {
            selectedIDs.remove(at: index)
            return .removed
        }
        guard ProRules.canUse(recipe, isPro: isPro) else { return .locked }
        guard selectedIDs.count < dishLimit else { return .full }
        selectedIDs.append(recipe.id)
        cookedStepIDs = []
        return .added
    }

    func usePreset(_ preset: Preset) -> Bool {
        guard isPro || !preset.isPro else { return false }
        selectedIDs = Array(preset.recipeIDs.prefix(dishLimit))
        cookedStepIDs = []
        shoppingChecked = []
        return true
    }

    /// 作り終えた：容器を冷蔵庫に入れ、選んだ品を空にする。はじめての段取りなら課金の画面を 1 回だけ出す
    func finishCooking() {
        ledger.items.removeAll(where: \.isSample)
        ledger.put(selectedRecipes, on: today, calendar: calendar)
        plansCompleted += 1
        selectedIDs = []
        cookedStepIDs = []
        shoppingChecked = []
        tab = .fridge
        // 調理の全画面が閉じてから出す（PlanView の onDismiss）
        pendingPaywall = plansCompleted == 1 && !isPro
    }

    // MARK: - 課金の画面（同じ日に 2 回は自動で出さない）

    func offerPaywall(_ reason: PaywallReason) {
        let key = DayKey.key(today, calendar: calendar)
        if reason.isAutomatic && paywallShownDay == key { return }
        if reason.isAutomatic { paywallShownDay = key }
        paywallReason = reason
        showPaywall = true
    }

    // MARK: - 見本とリセット

    func putSamples() {
        let day = calendar.startOfDay(for: today)
        func ago(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: day) ?? day }
        let samples: [(String, Int, Int)] = [("kyuri-asazuke", 3, 2), ("nikujaga", 3, 3), ("ninjin-rapee", 3, 2),
                                             ("kinpira", 1, 4), ("tori-chashu", 1, 3)]
        ledger.items = samples.compactMap { id, daysAgo, left in
            guard let r = RecipeBook.recipe(id) else { return nil }
            return FridgeItem(recipeID: r.id, name: r.name, madeOn: ago(daysAgo), keepsDays: r.keepsDays,
                              portions: r.portions, left: left, isSample: true)
        }
    }

    func resetAll() {
        ledger = FridgeLedger()
        selectedIDs = []
        plansCompleted = 0
        shoppingChecked = []
        cookedStepIDs = []
        putSamples()
    }

    private func loadScreenshotState() {
        onboardingDone = screenshotScene != "onboarding"
        putSamples()
        ledger.items = ledger.items.map { var item = $0; item.isSample = false; return item }
        // 記録の見本：直近 4 週の食べた食数（固定の並び）
        let pattern = [2, 0, 3, 1, 4, 2, 0, 1, 3, 2, 5, 0, 2, 1, 3, 2, 1, 0, 4, 2, 3, 1, 2, 0, 3, 2, 1]
        for (back, eaten) in pattern.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            ledger.logs[DayKey.key(day, calendar: calendar)] = DayLog(eaten: eaten, discarded: back == 19 ? 1 : 0)
        }
        ledger.startedOn = calendar.date(byAdding: .day, value: -26, to: calendar.startOfDay(for: today))
        ledger.lastDiscardOn = calendar.date(byAdding: .day, value: -19, to: calendar.startOfDay(for: today))
        plansCompleted = 3
        switch screenshotScene {
        case "empty":
            ledger = FridgeLedger()
        case "plan", "timeline", "cook", "shopping":
            selectedIDs = ["nikujaga", "saba-miso", "kyuri-asazuke"]
            tab = .plan
        case "planEmpty":
            tab = .plan
        case "recipes", "recipe":
            tab = .recipes
        default:
            break
        }
        if screenshotScene == "paywall" {
            paywallReason = .afterFirstPlan
            showPaywall = true
        }
    }

    private func save() {
        guard !loading, screenshotScene == nil else { return }
        let state = SavedState(ledger: ledger, selectedIDs: selectedIDs, kitchen: kitchen, plansCompleted: plansCompleted,
                               shoppingChecked: shoppingChecked, hapticsOn: hapticsOn, onboardingDone: onboardingDone,
                               paywallShownDay: paywallShownDay)
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }
}

struct SavedState: Codable {
    var ledger: FridgeLedger
    var selectedIDs: [String]
    var kitchen: KitchenSetup
    var plansCompleted: Int
    var shoppingChecked: Set<String>
    var hapticsOn: Bool
    var onboardingDone: Bool
    var paywallShownDay: String?
}

enum AppTab: Hashable { case fridge, plan, recipes, settings }

enum PaywallReason: Equatable {
    case menu, afterFirstPlan, lockedRecipe, dishLimit, heatmap

    var isAutomatic: Bool { self == .afterFirstPlan }

    var headline: String {
        switch self {
        case .menu: "段取り帖 Pro"
        case .afterFirstPlan: "はじめての段取り、おつかれさまでした"
        case .lockedRecipe: "このレシピは Pro の束に入っています"
        case .dishLimit: "無料では 1 回に 3 品まで"
        case .heatmap: "1 年分の食べきりカレンダー"
        }
    }
}
