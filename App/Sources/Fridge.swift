import Foundation

// 冷蔵庫の容器と、食べた・捨てたの記録。日付の計算はカレンダーを渡してテストできる形にする。

struct FridgeItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    let recipeID: String
    let name: String
    let madeOn: Date
    var keepsDays: Int
    let portions: Int
    var left: Int
    var frozen: Bool = false
    var isSample: Bool = false
}

enum Freshness: Equatable, Sendable {
    /// まだ余裕がある（あと n 日）
    case fresh(Int)
    /// あと 1 日
    case soon
    /// 今日まで
    case today
    /// めやすを過ぎた（n 日）
    case over(Int)

    var label: String {
        switch self {
        case .fresh(let days): "あと\(days)日"
        case .soon: "あと1日"
        case .today: "今日まで"
        case .over(let days): "\(days)日すぎ"
        }
    }

    /// 0 が新しい。並べる順と色の段階に使う
    var level: Int {
        switch self {
        case .fresh: 0
        case .soon: 1
        case .today: 2
        case .over: 3
        }
    }
}

struct DayLog: Codable, Hashable, Sendable {
    var eaten: Int = 0
    var discarded: Int = 0
}

enum DayKey {
    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }
}

/// 冷蔵庫の中身と記録（画面から切り離した値の型）
struct FridgeLedger: Codable, Equatable, Sendable {
    var items: [FridgeItem] = []
    var logs: [String: DayLog] = [:]
    /// 記録を始めた日（捨てずに続いた日数の起点）
    var startedOn: Date?
    var lastDiscardOn: Date?

    static let frozenKeepsDays = 30

    func freshness(of item: FridgeItem, today: Date, calendar: Calendar) -> Freshness {
        let left = item.keepsDays - DayKey.days(from: item.madeOn, to: today, calendar: calendar)
        switch left {
        case ..<0: return .over(-left)
        case 0: return .today
        case 1: return .soon
        default: return .fresh(left)
        }
    }

    /// 食べきりたい順（めやすが近い順、同じなら作った順）
    func sorted(today: Date, calendar: Calendar) -> [FridgeItem] {
        items.sorted {
            let a = freshness(of: $0, today: today, calendar: calendar)
            let b = freshness(of: $1, today: today, calendar: calendar)
            let da = $0.keepsDays - DayKey.days(from: $0.madeOn, to: today, calendar: calendar)
            let db = $1.keepsDays - DayKey.days(from: $1.madeOn, to: today, calendar: calendar)
            if a.level != b.level { return a.level > b.level }
            if da != db { return da < db }
            return $0.madeOn < $1.madeOn
        }
    }

    mutating func put(_ recipes: [Recipe], on date: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: date)
        if startedOn == nil { startedOn = day }
        for recipe in recipes {
            items.append(FridgeItem(recipeID: recipe.id, name: recipe.name, madeOn: day, keepsDays: recipe.keepsDays,
                                    portions: recipe.portions, left: recipe.portions))
        }
    }

    /// 1 食食べた。食べきったら容器を出す
    mutating func eat(_ id: UUID, portions: Int = 1, on date: Date, calendar: Calendar) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let eaten = min(max(1, portions), items[index].left)
        items[index].left -= eaten
        if !items[index].isSample { logs[DayKey.key(date, calendar: calendar), default: DayLog()].eaten += eaten }
        if items[index].left <= 0 { items.remove(at: index) }
    }

    mutating func eatAll(_ id: UUID, on date: Date, calendar: Calendar) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        eat(id, portions: item.left, on: date, calendar: calendar)
    }

    mutating func discard(_ id: UUID, on date: Date, calendar: Calendar) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        guard !item.isSample else { return }
        logs[DayKey.key(date, calendar: calendar), default: DayLog()].discarded += item.left
        lastDiscardOn = calendar.startOfDay(for: date)
    }

    /// 冷凍に回す：その日から 30 日もつことにする
    mutating func freeze(_ id: UUID, on date: Date, calendar: Calendar) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].frozen else { return }
        items[index].frozen = true
        items[index].keepsDays = DayKey.days(from: items[index].madeOn, to: date, calendar: calendar) + Self.frozenKeepsDays
    }

    // MARK: - 積み上げ

    var totalEaten: Int { logs.values.reduce(0) { $0 + $1.eaten } }
    var totalDiscarded: Int { logs.values.reduce(0) { $0 + $1.discarded } }

    /// 食べきり率（0〜100）。記録がなければ nil
    var eatRate: Int? {
        let all = totalEaten + totalDiscarded
        guard all > 0 else { return nil }
        return Int((Double(totalEaten) / Double(all) * 100).rounded())
    }

    /// 捨てずに続いた日数（最後に捨てた日の翌日、または始めた日から今日まで）
    func daysWithoutWaste(today: Date, calendar: Calendar) -> Int {
        if let last = lastDiscardOn { return max(0, DayKey.days(from: last, to: today, calendar: calendar)) }
        guard let start = startedOn else { return 0 }
        return max(0, DayKey.days(from: start, to: today, calendar: calendar) + 1)
    }

    /// 今日を含む直近 7 日に食べた食数
    func eatenThisWeek(today: Date, calendar: Calendar) -> Int {
        (0..<7).reduce(0) { sum, back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return sum }
            return sum + (logs[DayKey.key(day, calendar: calendar)]?.eaten ?? 0)
        }
    }

    /// 食べきりカレンダーのマス（古い順、weeks × 7）。今日の週の日曜から始まる列に揃える
    func heatmap(weeks: Int, today: Date, calendar: Calendar) -> [HeatCell] {
        let todayStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: todayStart) - 1   // 日曜 0
        guard let firstDay = calendar.date(byAdding: .day, value: -(weekday + 7 * (weeks - 1)), to: todayStart) else { return [] }
        return (0..<(weeks * 7)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let log = logs[DayKey.key(day, calendar: calendar)] ?? DayLog()
            return HeatCell(date: day, eaten: log.eaten, discarded: log.discarded, isFuture: day > todayStart)
        }
    }
}

struct HeatCell: Hashable, Sendable {
    let date: Date
    let eaten: Int
    let discarded: Int
    let isFuture: Bool

    /// 0〜4 の濃さ（食べた食数の区切りで決める）
    var level: Int {
        switch eaten {
        case 0: 0
        case 1: 1
        case 2...3: 2
        case 4...5: 3
        default: 4
        }
    }
}

/// 無料と Pro の境目（画面から切り離してテストする）
enum ProRules {
    static let freeDishLimit = 3
    static let proDishLimit = 8
    static let freeHeatmapWeeks = 4
    static let proHeatmapWeeks = 52

    /// 1 回目の段取りは、品数の制限なしで試せる
    static func dishLimit(isPro: Bool, plansCompleted: Int) -> Int {
        isPro || plansCompleted == 0 ? proDishLimit : freeDishLimit
    }

    static func canUse(_ recipe: Recipe, isPro: Bool) -> Bool { isPro || !recipe.isPro }
}
