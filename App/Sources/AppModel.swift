import Foundation
import Observation
import SwiftUI

/// 画面が見る状態。保存は UserDefaults の JSON 1 つ（端末の中だけ）。
@MainActor
@Observable
final class AppModel {
    var ledger = FridgeLedger() { didSet { save() } }
    /// コースに選んだ品（選んだ順。番号はこの順）
    var selectedIDs: [String] = [] { didSet { save() } }
    var kitchen = KitchenSetup() { didSet { save() } }
    var runs: [RunRecord] = [] { didSet { save() } }
    /// 走っている途中のラン
    var session: RunSession? { didSet { save() } }
    var shoppingChecked: Set<String> = [] { didSet { save() } }
    var hapticsOn = true { didSet { save() } }
    var onboardingDone = false { didSet { save() } }
    var paywallShownDay: String? { didSet { save() } }
    var ghostTrialsLeft = ProRules.freeGhostTrials { didSet { save() } }

    var tab: AppTab = .run
    var showRun = false
    /// ゴールした直後の結果（結果の画面を出す）
    var result: RunRecord?
    var showPaywall = false
    var pendingPaywall = false
    var paywallReason: PaywallReason = .menu

    let purchases: PurchaseStore
    let screenshotScene: String?
    @ObservationIgnored private var loading = true
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let calendar = Calendar.current
    /// スクリーンショットでは時刻を固定する（ラン中の経過時間がぶれないように）
    @ObservationIgnored private var fixedNow: Date?

    static let storageKey = "batchprep.state.v2"

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
            runs = saved.runs
            session = saved.session
            shoppingChecked = saved.shoppingChecked
            hapticsOn = saved.hapticsOn
            onboardingDone = saved.onboardingDone
            paywallShownDay = saved.paywallShownDay
            ghostTrialsLeft = saved.ghostTrialsLeft
        } else {
            putSamples()
        }
        loading = false
    }

    // MARK: - 権利

    var isPro: Bool { purchases.entitlements.isPro || screenshotScene == "pro" }
    var dishLimit: Int { ProRules.dishLimit(isPro: isPro, runsCompleted: runs.count) }
    var now: Date { fixedNow ?? Date() }
    var today: Date { now }

    // MARK: - コース（選んだ品）と段取り

    var selectedRecipes: [Recipe] { selectedIDs.compactMap(RecipeBook.recipe) }
    var plan: Plan { Scheduler.plan(selectedRecipes, kitchen: kitchen) }
    var courseBest: RunRecord? { RunMath.best(runs, courseKey: RunMath.courseKey(selectedIDs)) }

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
        return .added
    }

    func usePreset(_ preset: Preset) -> Bool {
        guard isPro || !preset.isPro else { return false }
        selectedIDs = Array(preset.recipeIDs.prefix(dishLimit))
        shoppingChecked = []
        return true
    }

    // MARK: - ラン

    /// 走っている途中のランの段取りとルート（選び直しても変わらないよう、始めたときの品と台所で計算する）
    var sessionPlan: Plan? {
        guard let session else { return nil }
        return Scheduler.plan(session.recipeIDs.compactMap(RecipeBook.recipe), kitchen: session.kitchen)
    }

    var sessionBest: RunRecord? {
        guard let session else { return nil }
        return RunMath.best(runs, courseKey: RunMath.courseKey(session.recipeIDs))
    }

    var canUseGhost: Bool {
        ProRules.canUseGhost(isPro: isPro, hasBest: courseBest != nil, trialsLeft: ghostTrialsLeft)
    }

    func startRun() {
        guard !selectedIDs.isEmpty else { return }
        let ghost = canUseGhost
        if ghost && !isPro { ghostTrialsLeft = max(0, ghostTrialsLeft - 1) }
        session = RunSession(startedAt: now, recipeIDs: selectedIDs, kitchen: kitchen, ghost: ghost)
        showRun = true
    }

    /// 今の工程を押した（できた／仕掛けた）
    func tap() {
        guard var current = session, let plan = sessionPlan else { return }
        let route = RunMath.route(plan)
        guard current.taps.count < route.count else { return }
        let elapsed = current.elapsed(at: now)
        current.taps.append(max(elapsed, current.taps.last ?? 0))
        session = current
    }

    /// 1 つ前に戻す（押しまちがい）
    func undoTap() {
        guard var current = session, !current.taps.isEmpty else { return }
        current.taps.removeLast()
        session = current
    }

    func abandonRun() {
        session = nil
        showRun = false
    }

    /// ゴール：記録を残し、作った品を冷蔵庫に入れる。はじめてのランなら、結果を閉じたあとに課金の画面を 1 回だけ
    func finishRun() {
        guard let current = session, let plan = sessionPlan else { return }
        let route = RunMath.route(plan)
        let seconds = RunMath.finishSeconds(route: route, taps: current.taps).map { min($0, current.elapsed(at: now)) }
            ?? current.elapsed(at: now)
        var finished = current
        while finished.taps.count < route.count { finished.taps.append(seconds) }
        let recipes = current.recipeIDs.compactMap(RecipeBook.recipe)
        let record = RunMath.makeRecord(session: finished, plan: plan, route: route, finishedAt: max(seconds, 1),
                                        date: now, names: recipes.map(\.name))
        ledger.items.removeAll(where: \.isSample)
        ledger.put(recipes, on: today, calendar: calendar, runID: record.id)
        runs.append(record)
        session = nil
        selectedIDs = []
        shoppingChecked = []
        showRun = false
        pendingPaywall = runs.count == 1 && !isPro
        // ラン中の全画面が閉じてから結果を出す
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.result = record
        }
    }

    func status(of record: RunRecord) -> EatStatus { ledger.status(ofRun: record.id) }

    var clearStreak: Int { RunMath.clearStreak(runs) { self.ledger.status(ofRun: $0.id) } }

    var savedMinutesTotal: Int {
        runs.reduce(0) { $0 + max(0, $1.sequentialSeconds - $1.seconds) } / 60
    }

    // MARK: - 課金の画面（同じ日に 2 回は自動で出さない）

    func offerPaywall(_ reason: PaywallReason) {
        let key = DayKey.key(today, calendar: calendar)
        if reason.isAutomatic && paywallShownDay == key { return }
        if reason.isAutomatic { paywallShownDay = key }
        paywallReason = reason
        showPaywall = true
    }

    /// ほかのシートを閉じた直後に出す（閉じる動きと重ならないよう少し待つ）
    func offerPaywallSoon(_ reason: PaywallReason) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            self.offerPaywall(reason)
        }
    }

    /// 結果の画面を閉じたとき
    func closeResult() {
        result = nil
        if pendingPaywall {
            pendingPaywall = false
            offerPaywall(.afterFirstRun)
        }
    }

    // MARK: - 見本とリセット

    func putSamples() {
        let day = calendar.startOfDay(for: today)
        func ago(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: day) ?? day }
        let samples: [(String, Int, Int)] = [("kyuri-asazuke", 3, 2), ("nikujaga", 2, 3), ("ninjin-rapee", 2, 2),
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
        runs = []
        session = nil
        shoppingChecked = []
        ghostTrialsLeft = ProRules.freeGhostTrials
        putSamples()
    }

    /// CI のスクリーンショット用の状態（起動引数 -screenshotScene <名前>）
    private func loadScreenshotState() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 19, minute: 30)) ?? Date()
        fixedNow = base
        onboardingDone = screenshotScene != "onboarding"
        let day = calendar.startOfDay(for: base)
        func ago(_ n: Int, hour: Int = 18) -> Date {
            calendar.date(byAdding: .hour, value: hour, to: calendar.date(byAdding: .day, value: -n, to: day) ?? day) ?? day
        }
        // 過去のラン（今週のお題のコースで、自己ベストあり）
        let challenge = WeeklyChallenge.preset(for: base, calendar: calendar)
        let samples: [([String], Int, Int, Int, Int)] = [
            (["nikujaga", "kinpira", "kyuri-asazuke"], 2, 2_892, 2_400, 52),
            (challenge.recipeIDs, 5, 2_538, 2_400, 61),
            (["tori-chashu", "hijiki", "ninjin-rapee"], 9, 3_310, 3_000, 47),
            (challenge.recipeIDs, 12, 2_710, 2_400, 55),
            (["nikujaga", "kinpira", "kyuri-asazuke"], 16, 3_105, 2_400, 38),
        ]
        var made: [RunRecord] = []
        for (ids, daysAgo, seconds, _, parallel) in samples {
            let recipes = ids.compactMap(RecipeBook.recipe)
            let plan = Scheduler.plan(recipes)
            let route = RunMath.route(plan)
            let ratio = Double(seconds) / Double(max(1, plan.totalMinutes * 60))
            let splits = route.map { Int(Double($0.checkpointMinutes * 60) * ratio) }
            made.append(RunRecord(recipeIDs: ids, names: recipes.map(\.name), date: ago(daysAgo), seconds: seconds,
                                  parSeconds: plan.totalMinutes * 60, sequentialSeconds: plan.sequentialMinutes * 60,
                                  parallelRate: parallel, splits: splits, burners: 2))
        }
        runs = made
        // 冷蔵庫：最近のランで作った品が残っている
        ledger.startedOn = calendar.date(byAdding: .day, value: -20, to: day)
        let latest = made[0]
        let items: [(String, Int, Int, UUID?)] = [("kyuri-asazuke", 2, 1, latest.id), ("nikujaga", 2, 2, latest.id),
                                                  ("kinpira", 2, 3, latest.id), ("tori-chashu", 0, 4, nil),
                                                  ("hijiki", 4, 1, nil), ("kabocha-ni", 1, 2, nil)]
        ledger.items = items.compactMap { id, daysAgo, left, run in
            guard let r = RecipeBook.recipe(id) else { return nil }
            return FridgeItem(recipeID: r.id, name: r.name, madeOn: calendar.date(byAdding: .day, value: -daysAgo, to: day) ?? day,
                              keepsDays: r.keepsDays, portions: r.portions, left: left, runID: run)
        }
        for back in 0..<20 {
            guard let d = calendar.date(byAdding: .day, value: -back, to: day) else { continue }
            ledger.logs[DayKey.key(d, calendar: calendar)] = DayLog(eaten: [2, 1, 3, 0, 2, 1, 2][back % 7], discarded: 0)
        }
        switch screenshotScene {
        case "plan", "shopping":
            selectedIDs = challenge.recipeIDs
            tab = .run
        case "planBig":
            selectedIDs = ["nikujaga", "saba-miso", "kinpira", "kyuri-asazuke", "ninjin-rapee"]
            tab = .run
        case "cook", "cookEnd":
            selectedIDs = challenge.recipeIDs
            let recipes = challenge.recipeIDs.compactMap(RecipeBook.recipe)
            let plan = Scheduler.plan(recipes, kitchen: kitchen)
            let route = RunMath.route(plan)
            let count = screenshotScene == "cook" ? min(4, route.count - 1) : route.count
            let taps = route.prefix(count).map { max(0, $0.checkpointMinutes * 60 - 50) }
            let elapsed = screenshotScene == "cook" ? (taps.last ?? 0) + 95 : (taps.last ?? 0) + 60
            session = RunSession(startedAt: base.addingTimeInterval(-Double(elapsed)), recipeIDs: challenge.recipeIDs,
                                 kitchen: kitchen, taps: Array(taps), ghost: true)
            showRun = true
        case "result":
            result = made[1]
        case "fridge", "empty":
            tab = .fridge
            if screenshotScene == "empty" { ledger.items = [] }
        case "recipes", "recipe":
            tab = .recipes
        case "paywall":
            paywallReason = .afterFirstRun
            showPaywall = true
        default:
            break
        }
    }

    private func save() {
        guard !loading, screenshotScene == nil else { return }
        let state = SavedState(ledger: ledger, selectedIDs: selectedIDs, kitchen: kitchen, runs: runs, session: session,
                               shoppingChecked: shoppingChecked, hapticsOn: hapticsOn, onboardingDone: onboardingDone,
                               paywallShownDay: paywallShownDay, ghostTrialsLeft: ghostTrialsLeft)
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }
}

struct SavedState: Codable {
    var ledger: FridgeLedger
    var selectedIDs: [String]
    var kitchen: KitchenSetup
    var runs: [RunRecord]
    var session: RunSession?
    var shoppingChecked: Set<String>
    var hapticsOn: Bool
    var onboardingDone: Bool
    var paywallShownDay: String?
    var ghostTrialsLeft: Int
}

enum AppTab: Hashable { case run, fridge, recipes }

enum PaywallReason: Equatable {
    case menu, afterFirstRun, lockedRecipe, dishLimit, ghost, history

    var isAutomatic: Bool { self == .afterFirstRun }

    var headline: String {
        switch self {
        case .menu: "段取りラン Pro"
        case .afterFirstRun: "はじめてのラン、完走です"
        case .lockedRecipe: "このレシピは Pro の束に入っています"
        case .dishLimit: "無料では 1 回に 3 品まで"
        case .ghost: "自己ベストのゴーストと走る"
        case .history: "全部のランを見返す"
        }
    }
}
