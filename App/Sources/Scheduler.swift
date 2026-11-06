import Foundation

// 段取りの計算。何品かの工程を、手（1 本）・コンロ（口の数）・レンジ（1）・グリル（1）を資源にして
// 1 本のタイムラインに並べる。残りの工程が長い品から先に始める（クリティカルパスの貪欲法）。
// 待つだけの工程（煮る・漬ける・レンジ）は手を使わないので、そのあいだに別の品の手の工程を進める。

struct KitchenSetup: Equatable, Codable, Sendable {
    var burners: Int = 2
    var micros: Int = 1
    var ovens: Int = 1

    func capacity(of device: Device) -> Int {
        switch device {
        case .none: Int.max
        case .burner: max(1, burners)
        case .micro: max(1, micros)
        case .oven: max(1, ovens)
        }
    }
}

struct PlannedStep: Identifiable, Hashable, Sendable {
    var id: String { "\(recipeID)#\(stepIndex)" }
    let recipeID: String
    let recipeName: String
    let stepIndex: Int
    let step: RecipeStep
    let start: Int
    let end: Int
    /// 同じ道具の何番目を使うか（コンロ 1・コンロ 2）。待つだけで道具なしの工程は、重ならない行の番号
    let slot: Int
}

struct Plan: Equatable, Sendable {
    let steps: [PlannedStep]
    /// 段取りどおりに作ったときの合計（分）
    var totalMinutes: Int { steps.map(\.end).max() ?? 0 }
    /// 1 品ずつ順に作ったときの合計（分）
    let sequentialMinutes: Int
    var handsMinutes: Int { steps.filter(\.step.hands).reduce(0) { $0 + $1.step.minutes } }
    var savedMinutes: Int { max(0, sequentialMinutes - totalMinutes) }
    var isEmpty: Bool { steps.isEmpty }

    /// 待つだけで道具なしの工程が、同時にいくつ重なるか（タイムラインの「待ち」の行の数）
    var waitRows: Int {
        (steps.filter { !$0.step.hands && $0.step.device == .none }.map(\.slot).max() ?? -1) + 1
    }
}

enum Scheduler {
    static func plan(_ recipes: [Recipe], kitchen: KitchenSetup = KitchenSetup()) -> Plan {
        let recipes = recipes.filter { !$0.steps.isEmpty }
        let sequential = recipes.reduce(0) { $0 + $1.totalMinutes }
        guard !recipes.isEmpty else { return Plan(steps: [], sequentialMinutes: 0) }

        var next = Array(repeating: 0, count: recipes.count)        // 次に始める工程
        var readyAt = Array(repeating: 0, count: recipes.count)     // 前の工程が終わる時刻
        var handsFreeAt = 0
        var deviceFreeAt: [Device: [Int]] = [:]
        for device in [Device.burner, .micro, .oven] {
            deviceFreeAt[device] = Array(repeating: 0, count: kitchen.capacity(of: device))
        }
        var waitRowsFreeAt: [Int] = []
        var result: [PlannedStep] = []

        func remaining(_ r: Int) -> Int { recipes[r].steps[next[r]...].reduce(0) { $0 + $1.minutes } }

        var now = 0
        let totalSteps = recipes.reduce(0) { $0 + $1.steps.count }
        var guardCount = 0
        while result.count < totalSteps, guardCount < 10_000 {
            guardCount += 1
            // 今始められる品を、残りの長い順に（同じなら選んだ順）
            let candidates = recipes.indices
                .filter { next[$0] < recipes[$0].steps.count && readyAt[$0] <= now }
                .sorted { (remaining($0), -$0) > (remaining($1), -$1) }
            var started = false
            for r in candidates {
                let step = recipes[r].steps[next[r]]
                if step.hands && handsFreeAt > now { continue }
                var slot = 0
                if step.device != .none {
                    guard let free = deviceFreeAt[step.device]?.firstIndex(where: { $0 <= now }) else { continue }
                    slot = free
                    deviceFreeAt[step.device]?[free] = now + step.minutes
                } else if !step.hands {
                    if let free = waitRowsFreeAt.firstIndex(where: { $0 <= now }) {
                        slot = free
                        waitRowsFreeAt[free] = now + step.minutes
                    } else {
                        slot = waitRowsFreeAt.count
                        waitRowsFreeAt.append(now + step.minutes)
                    }
                }
                if step.hands { handsFreeAt = now + step.minutes }
                result.append(PlannedStep(recipeID: recipes[r].id, recipeName: recipes[r].name, stepIndex: next[r],
                                          step: step, start: now, end: now + step.minutes, slot: slot))
                readyAt[r] = now + step.minutes
                next[r] += 1
                started = true
            }
            if started { continue }
            // 何も始められなければ、次に何かが空く時刻まで進める
            var events = readyAt.filter { $0 > now }
            if handsFreeAt > now { events.append(handsFreeAt) }
            for times in deviceFreeAt.values { events += times.filter { $0 > now } }
            guard let soonest = events.min() else { break }
            now = soonest
        }
        result.sort { ($0.start, $0.step.hands ? 0 : 1, $0.recipeName) < ($1.start, $1.step.hands ? 0 : 1, $1.recipeName) }
        return Plan(steps: result, sequentialMinutes: sequential)
    }
}
