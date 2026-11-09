import Foundation

// 段取りを「ルート」として走る（タイムアタック）。画面から切り離した計算だけを置き、テストで確かめる。
// - ルート：段取りの工程を、押す順（手の工程は終わったとき、待つ工程は仕掛けたとき）に並べたもの
// - スプリット：ルートの工程ごとに押した時刻（ランの始まりからの秒）
// - 手際：目安（段取りの合計）との比でランク、1 品ずつ作るより何倍速か、2 つ以上が同時に進んでいた割合（並行）

/// ルートの 1 歩
struct RouteStep: Identifiable, Hashable, Sendable {
    let planned: PlannedStep
    var id: String { planned.id }
    /// 待つだけの工程（煮る・漬ける・レンジ）は「仕掛けた」で押す。手の工程は「できた」で押す
    var isWait: Bool { !planned.step.hands }
    /// 押す目安の時刻（分）
    var checkpointMinutes: Int { isWait ? planned.start : planned.end }
}

/// 仕掛けて動いている待つ工程
struct RunningWait: Identifiable, Hashable, Sendable {
    let step: RouteStep
    let endsAt: Int
    var id: String { step.id }
}

/// 実際に何かが進んでいた区間（秒）
struct Span: Hashable, Sendable {
    let start: Int
    let end: Int
}

enum Rank: String, Codable, Sendable, CaseIterable {
    case s = "S", a = "A", b = "B", c = "C", d = "D"

    var title: String {
        switch self {
        case .s: "神段取り"
        case .a: "目安どおり"
        case .b: "あと少し"
        case .c: "ていねい"
        case .d: "ゆっくり"
        }
    }
}

/// 1 本のランの記録
struct RunRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    let recipeIDs: [String]
    let names: [String]
    let date: Date
    let seconds: Int
    let parSeconds: Int
    let sequentialSeconds: Int
    /// 2 つ以上が同時に進んでいた割合（0〜100）
    let parallelRate: Int
    /// ルートの工程ごとに押した時刻（秒）
    let splits: [Int]
    let burners: Int

    var courseKey: String { RunMath.courseKey(recipeIDs) }
    var rank: Rank { RunMath.rank(seconds: seconds, par: parSeconds) }
    var parDelta: Int { seconds - parSeconds }
    var speedup: Double { RunMath.speedup(seconds: seconds, sequentialSeconds: sequentialSeconds) }
}

/// 走っている途中のラン（アプリを閉じても続きから戻れるよう保存する）
struct RunSession: Codable, Equatable, Sendable {
    let startedAt: Date
    let recipeIDs: [String]
    let kitchen: KitchenSetup
    /// ルートの順に、押した時刻（秒）
    var taps: [Int] = []
    /// 自己ベストのゴーストを使うか（Pro か、お試しの 1 回）
    var ghost: Bool = false

    func elapsed(at now: Date) -> Int { max(0, Int(now.timeIntervalSince(startedAt))) }
}

enum RunMath {
    static func courseKey(_ ids: [String]) -> String { ids.sorted().joined(separator: "+") }

    /// 押す順に並べる。同じ時刻なら、先に始まった工程（同じ品の前の工程）が先
    static func route(_ plan: Plan) -> [RouteStep] {
        plan.steps.map { RouteStep(planned: $0) }.sorted { a, b in
            if a.checkpointMinutes != b.checkpointMinutes { return a.checkpointMinutes < b.checkpointMinutes }
            if a.planned.start != b.planned.start { return a.planned.start < b.planned.start }
            if a.planned.recipeName != b.planned.recipeName { return a.planned.recipeName < b.planned.recipeName }
            return a.planned.stepIndex < b.planned.stepIndex
        }
    }

    /// 押した時刻から、実際に進んでいた区間を作る。
    /// 手の工程は「前に何かを押した時刻 → 押した時刻」、待つ工程は「仕掛けた時刻 → それ＋めやすの分」
    static func spans(route: [RouteStep], taps: [Int]) -> [Span] {
        var result: [Span] = []
        var previous = 0
        for (index, tap) in taps.enumerated() where index < route.count {
            let step = route[index]
            if step.isWait {
                result.append(Span(start: tap, end: tap + step.planned.step.minutes * 60))
            } else {
                result.append(Span(start: min(previous, tap), end: tap))
            }
            previous = tap
        }
        return result
    }

    /// 全部押したあと、ゴールになる時刻（最後に押した時刻と、待つ工程が終わる時刻の遅いほう）。押し終わっていなければ nil
    static func finishSeconds(route: [RouteStep], taps: [Int]) -> Int? {
        guard !route.isEmpty, taps.count >= route.count else { return nil }
        let waitsEnd = spans(route: route, taps: taps).map(\.end).max() ?? 0
        return max(taps.last ?? 0, waitsEnd)
    }

    /// 今動いている待つ工程（仕掛けて、まだ終わっていない）
    static func running(route: [RouteStep], taps: [Int], now: Int) -> [RunningWait] {
        var result: [RunningWait] = []
        for (index, tap) in taps.enumerated() where index < route.count && route[index].isWait {
            let end = tap + route[index].planned.step.minutes * 60
            if end > now { result.append(RunningWait(step: route[index], endsAt: end)) }
        }
        return result
    }

    /// 2 つ以上が同時に進んでいた時間 ÷ ランの時間（0〜100）
    static func parallelRate(_ spans: [Span], total: Int) -> Int {
        guard total > 0 else { return 0 }
        var events: [(time: Int, delta: Int)] = []
        for span in spans where span.end > span.start {
            events.append((time: min(span.start, total), delta: 1))
            events.append((time: min(span.end, total), delta: -1))
        }
        events.sort { a, b in a.time != b.time ? a.time < b.time : a.delta < b.delta }
        var active = 0
        var last = 0
        var overlapped = 0
        for event in events {
            if active >= 2 { overlapped += event.time - last }
            active += event.delta
            last = event.time
        }
        return Int((Double(overlapped) / Double(total) * 100).rounded())
    }

    /// 目安との比でランク。S は目安の 9 割以内
    static func rank(seconds: Int, par: Int) -> Rank {
        guard par > 0 else { return .a }
        let ratio = Double(seconds) / Double(par)
        if ratio <= 0.9 { return .s }
        if ratio <= 1.0 { return .a }
        if ratio <= 1.15 { return .b }
        if ratio <= 1.35 { return .c }
        return .d
    }

    /// 1 品ずつ順に作るより何倍速か（小数 1 桁）
    static func speedup(seconds: Int, sequentialSeconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return (Double(sequentialSeconds) / Double(seconds) * 10).rounded() / 10
    }

    /// 目安との差（秒）。ルートの index の工程を、目安より何秒早く（負）・遅く押したか
    static func splitDelta(route: [RouteStep], taps: [Int], index: Int) -> Int? {
        guard index >= 0, index < route.count, index < taps.count else { return nil }
        return taps[index] - route[index].checkpointMinutes * 60
    }

    /// コンボ：最後から続けて目安以内に押した数
    static func combo(route: [RouteStep], taps: [Int]) -> Int {
        var count = 0
        for index in stride(from: taps.count - 1, through: 0, by: -1) {
            guard let delta = splitDelta(route: route, taps: taps, index: index), delta <= 0 else { break }
            count += 1
        }
        return count
    }

    /// 自己ベストのゴースト：最後に押した工程を、自己ベストのときより何秒早く（負）・遅く押したか
    static func ghostDelta(best: RunRecord?, taps: [Int]) -> Int? {
        guard let best, let last = taps.last, taps.count <= best.splits.count else { return nil }
        return last - best.splits[taps.count - 1]
    }

    static func makeRecord(session: RunSession, plan: Plan, route: [RouteStep], finishedAt seconds: Int, date: Date,
                           names: [String]) -> RunRecord {
        let actual = spans(route: route, taps: session.taps)
        return RunRecord(recipeIDs: session.recipeIDs, names: names, date: date, seconds: seconds,
                         parSeconds: plan.totalMinutes * 60, sequentialSeconds: plan.sequentialMinutes * 60,
                         parallelRate: parallelRate(actual, total: seconds), splits: session.taps,
                         burners: session.kitchen.burners)
    }

    /// 同じ品の組み合わせ（コース）での自己ベスト
    static func best(_ records: [RunRecord], courseKey: String, excluding id: UUID? = nil) -> RunRecord? {
        records.filter { $0.courseKey == courseKey && $0.id != id }.min { $0.seconds < $1.seconds }
    }

    /// この記録が出たとき、自己ベストを更新したか（そのコースの初めてのランも自己ベスト）
    static func isPersonalBest(_ record: RunRecord, in records: [RunRecord]) -> Bool {
        let earlier = records.filter { $0.date <= record.date }
        guard let before = best(earlier, courseKey: record.courseKey, excluding: record.id) else { return true }
        return record.seconds < before.seconds
    }

    /// 完食が続いたラン数：新しい順に、まだ食べている途中のものは飛ばし、捨てたものが出たら止まる
    static func clearStreak(_ records: [RunRecord], status: (RunRecord) -> EatStatus) -> Int {
        var streak = 0
        for record in records.sorted(by: { $0.date > $1.date }) {
            switch status(record) {
            case .eating: continue
            case .cleared: streak += 1
            case .spoiled: return streak
            }
        }
        return streak
    }
}

/// ランで作った品を食べきったか
enum EatStatus: Equatable, Sendable {
    /// まだ冷蔵庫に残っている
    case eating
    /// 全部食べきった（完走）
    case cleared
    /// 捨てたものがある
    case spoiled
}

/// 今週のお題（週ごとに無料の組み合わせを回す。だれでも同じお題）
enum WeeklyChallenge {
    static func preset(for date: Date, calendar: Calendar) -> Preset {
        let free = RecipeBook.presets.filter { !$0.isPro }
        let week = calendar.component(.weekOfYear, from: date) + calendar.component(.yearForWeekOfYear, from: date) * 53
        return free[week % free.count]
    }

    /// その週のランだけ
    static func runsThisWeek(_ records: [RunRecord], courseKey: String, today: Date, calendar: Calendar) -> [RunRecord] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        return records.filter { $0.courseKey == courseKey && week.contains($0.date) }
    }
}

/// 無料と Pro の境目（画面から切り離してテストする）
enum ProRules {
    static let freeDishLimit = 3
    static let proDishLimit = 8
    /// 無料で見られるランの記録の数（新しい順）
    static let freeHistory = 5
    /// ゴーストを無料で試せる回数
    static let freeGhostTrials = 1

    /// はじめてのランは、品数の制限なしで試せる
    static func dishLimit(isPro: Bool, runsCompleted: Int) -> Int {
        isPro || runsCompleted == 0 ? proDishLimit : freeDishLimit
    }

    static func canUse(_ recipe: Recipe, isPro: Bool) -> Bool { isPro || !recipe.isPro }

    static func visibleHistory(_ records: [RunRecord], isPro: Bool) -> [RunRecord] {
        let sorted = records.sorted { $0.date > $1.date }
        return isPro ? sorted : Array(sorted.prefix(freeHistory))
    }

    /// ゴーストが使えるか：自己ベストがあり、Pro か、お試しが残っている
    static func canUseGhost(isPro: Bool, hasBest: Bool, trialsLeft: Int) -> Bool {
        hasBest && (isPro || trialsLeft > 0)
    }
}
