import Foundation
import Testing
@testable import BatchPrep

private func step(_ minutes: Int, hands: Bool, _ device: Device = .none, _ text: String = "工程") -> RecipeStep {
    RecipeStep(text: text, minutes: minutes, hands: hands, device: device)
}

private func recipe(_ id: String, _ steps: [RecipeStep], ingredients: [Ingredient] = [], pro: Bool = false) -> Recipe {
    Recipe(id: id, name: id, category: .side, portions: 4, keepsDays: 3, freezable: false, isPro: pro,
           ingredients: ingredients, steps: steps)
}

private var tokyo: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return c
}

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    tokyo.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

struct RecipeDataTests {
    @Test func theHandWrittenDataParses() throws {
        let recipes = try RecipeParser.parse(RecipeData.text)
        #expect(recipes.count >= 48)
        #expect(recipes.filter { !$0.isPro }.count >= 24)
    }

    @Test func everyRecipeIsComplete() throws {
        for r in try RecipeParser.parse(RecipeData.text) {
            #expect(!r.ingredients.isEmpty, "\(r.id) に材料がない")
            #expect(!r.steps.isEmpty, "\(r.id) に工程がない")
            #expect(r.portions > 0 && r.keepsDays > 0, "\(r.id) の量か日持ちが 0")
        }
    }

    @Test func idsAreUnique() {
        let ids = RecipeBook.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func presetsPointToRealRecipesAndRespectPro() {
        for preset in RecipeBook.presets {
            let recipes = preset.recipeIDs.compactMap(RecipeBook.recipe)
            #expect(recipes.count == preset.recipeIDs.count, "\(preset.id) に無い品がある")
            #expect(recipes.count <= ProRules.proDishLimit)
            if !preset.isPro {
                #expect(recipes.allSatisfy { !$0.isPro }, "無料の組み合わせ \(preset.id) に Pro の品がある")
                #expect(recipes.count <= ProRules.freeDishLimit)
            }
        }
    }

    @Test func badLinesAreRejected() {
        #expect(throws: RecipeParseError.self) { try RecipeParser.parse("R|a|名前|main|4|3|0|0\nS|切る|x|h|-") }
        #expect(throws: RecipeParseError.self) { try RecipeParser.parse("X|なにか") }
    }
}

struct SchedulerTests {
    @Test func emptyPlanIsZero() {
        let plan = Scheduler.plan([])
        #expect(plan.isEmpty)
        #expect(plan.totalMinutes == 0)
    }

    @Test func handsWorkDuringAnotherDishsSimmer() {
        // A: 切る 10 → 煮る 20（待つ）。B: 切る 10 → 炒める 5
        let a = recipe("a", [step(10, hands: true), step(20, hands: false, .burner)])
        let b = recipe("b", [step(10, hands: true), step(5, hands: true, .burner)])
        let plan = Scheduler.plan([a, b])
        #expect(plan.sequentialMinutes == 45)
        #expect(plan.totalMinutes == 30)   // A を先に切り、煮ているあいだに B を切って炒める
        #expect(plan.savedMinutes == 15)
    }

    @Test func handsNeverOverlap() {
        let plan = Scheduler.plan(Array(RecipeBook.all.prefix(6)))
        let hands = plan.steps.filter(\.step.hands).sorted { $0.start < $1.start }
        for (x, y) in zip(hands, hands.dropFirst()) {
            #expect(x.end <= y.start, "\(x.id) と \(y.id) で手が重なる")
        }
    }

    @Test(arguments: [1, 2, 3])
    func burnersNeverExceedTheKitchen(burners: Int) {
        let plan = Scheduler.plan(Array(RecipeBook.all.prefix(8)), kitchen: KitchenSetup(burners: burners))
        let onBurner = plan.steps.filter { $0.step.device == .burner }
        for minute in 0..<plan.totalMinutes {
            let busy = onBurner.filter { $0.start <= minute && minute < $0.end }
            #expect(busy.count <= burners)
            #expect(Set(busy.map(\.slot)).count == busy.count)
        }
    }

    @Test func stepsOfADishStayInOrder() {
        let plan = Scheduler.plan(Array(RecipeBook.all.prefix(5)))
        for r in RecipeBook.all.prefix(5) {
            let mine = plan.steps.filter { $0.recipeID == r.id }.sorted { $0.stepIndex < $1.stepIndex }
            #expect(mine.count == r.steps.count)
            for (x, y) in zip(mine, mine.dropFirst()) { #expect(x.end <= y.start) }
        }
    }

    @Test func neverSlowerThanCookingOneByOne() {
        for preset in RecipeBook.presets {
            let plan = Scheduler.plan(preset.recipeIDs.compactMap(RecipeBook.recipe))
            #expect(plan.totalMinutes <= plan.sequentialMinutes, "\(preset.id)")
        }
    }

    @Test func moreBurnersIsNeverSlower() {
        let dishes = RecipeBook.presets.first { $0.id == "feast" }!.recipeIDs.compactMap(RecipeBook.recipe)
        let one = Scheduler.plan(dishes, kitchen: KitchenSetup(burners: 1)).totalMinutes
        let three = Scheduler.plan(dishes, kitchen: KitchenSetup(burners: 3)).totalMinutes
        #expect(three <= one)
    }
}

struct ShoppingTests {
    @Test func sameIngredientIsMergedAcrossDishes() {
        let onion = { (amount: Double) in Ingredient(name: "玉ねぎ", amount: amount, unit: "個", aisle: .veg) }
        let a = recipe("肉じゃが", [step(1, hands: true)], ingredients: [onion(1)])
        let b = recipe("南蛮漬け", [step(1, hands: true)], ingredients: [onion(0.5), Ingredient(name: "酢", amount: 4, unit: "大さじ", aisle: .season)])
        let groups = ShoppingList.build([a, b])
        let veg = groups.first { $0.aisle == .veg }!.items
        #expect(veg.count == 1)
        #expect(veg[0].amount == 1.5)
        #expect(veg[0].amountText == "1と1/2個")
        #expect(veg[0].usedIn == ["肉じゃが", "南蛮漬け"])
        #expect(groups.map(\.aisle) == [.veg, .season])
    }

    @Test(arguments: [(0.5, "1/2"), (2, "2"), (0.25, "1/4"), (1.75, "1と3/4"), (1.2, "1.2")])
    func amountsReadNaturally(value: Double, text: String) {
        #expect(ShoppingList.format(value) == text)
    }
}

struct FridgeTests {
    let cal = tokyo

    func ledgerWithNikujaga(on date: Date) -> (FridgeLedger, UUID) {
        var ledger = FridgeLedger()
        let r = recipe("nikujaga", [step(1, hands: true)])
        ledger.put([r], on: date, calendar: cal)
        return (ledger, ledger.items[0].id)
    }

    @Test func freshnessCountsDownByDay() {
        let (ledger, _) = ledgerWithNikujaga(on: day(2026, 11, 1))   // 日持ち 3
        let item = ledger.items[0]
        #expect(ledger.freshness(of: item, today: day(2026, 11, 1), calendar: cal) == .fresh(3))
        #expect(ledger.freshness(of: item, today: day(2026, 11, 3), calendar: cal) == .soon)
        #expect(ledger.freshness(of: item, today: day(2026, 11, 4), calendar: cal) == .today)
        #expect(ledger.freshness(of: item, today: day(2026, 11, 6), calendar: cal) == .over(2))
    }

    @Test func eatingRemovesTheContainerWhenEmptyAndLogs() {
        var (ledger, id) = ledgerWithNikujaga(on: day(2026, 11, 1))
        ledger.eat(id, on: day(2026, 11, 2), calendar: cal)
        #expect(ledger.items[0].left == 3)
        ledger.eatAll(id, on: day(2026, 11, 3), calendar: cal)
        #expect(ledger.items.isEmpty)
        #expect(ledger.totalEaten == 4)
        #expect(ledger.eatRate == 100)
    }

    @Test func discardingCountsLeftoversAndResetsTheStreak() {
        var (ledger, id) = ledgerWithNikujaga(on: day(2026, 11, 1))
        ledger.eat(id, on: day(2026, 11, 1), calendar: cal)
        #expect(ledger.daysWithoutWaste(today: day(2026, 11, 4), calendar: cal) == 4)
        ledger.discard(id, on: day(2026, 11, 5), calendar: cal)
        #expect(ledger.totalDiscarded == 3)
        #expect(ledger.eatRate == 25)
        #expect(ledger.daysWithoutWaste(today: day(2026, 11, 5), calendar: cal) == 0)
        #expect(ledger.daysWithoutWaste(today: day(2026, 11, 8), calendar: cal) == 3)
    }

    @Test func samplesDoNotCountInTheRecord() {
        var ledger = FridgeLedger()
        ledger.items = [FridgeItem(recipeID: "x", name: "見本", madeOn: day(2026, 11, 1), keepsDays: 3, portions: 2, left: 2, isSample: true)]
        ledger.eatAll(ledger.items[0].id, on: day(2026, 11, 1), calendar: cal)
        #expect(ledger.totalEaten == 0)
        #expect(ledger.eatRate == nil)
    }

    @Test func freezingGivesThirtyDaysFromToday() {
        var (ledger, id) = ledgerWithNikujaga(on: day(2026, 11, 1))
        ledger.freeze(id, on: day(2026, 11, 3), calendar: cal)
        let item = ledger.items[0]
        #expect(item.frozen)
        #expect(ledger.freshness(of: item, today: day(2026, 11, 3), calendar: cal) == .fresh(30))
    }

    @Test func soonestComesFirst() {
        var ledger = FridgeLedger()
        let long = Recipe(id: "long", name: "long", category: .pickle, portions: 2, keepsDays: 7, freezable: false, isPro: false, ingredients: [], steps: [])
        let short = Recipe(id: "short", name: "short", category: .side, portions: 2, keepsDays: 2, freezable: false, isPro: false, ingredients: [], steps: [])
        ledger.put([long, short], on: day(2026, 11, 1), calendar: cal)
        #expect(ledger.sorted(today: day(2026, 11, 2), calendar: cal).map(\.recipeID) == ["short", "long"])
    }

    @Test func heatmapEndsThisWeekAndMarksTheFuture() {
        var (ledger, id) = ledgerWithNikujaga(on: day(2026, 11, 4))
        ledger.eat(id, on: day(2026, 11, 4), calendar: cal)          // 水曜
        let cells = ledger.heatmap(weeks: 4, today: day(2026, 11, 4), calendar: cal)
        #expect(cells.count == 28)
        #expect(cal.component(.weekday, from: cells[0].date) == 1)   // 日曜から
        #expect(cells.first { cal.isDate($0.date, inSameDayAs: day(2026, 11, 4)) }?.level == 1)
        #expect(cells.last?.isFuture == true)
        #expect(ledger.eatenThisWeek(today: day(2026, 11, 6), calendar: cal) == 1)
    }

    @Test func savedStateRoundTrips() throws {
        let (ledger, _) = ledgerWithNikujaga(on: day(2026, 11, 1))
        let data = try JSONEncoder().encode(ledger)
        #expect(try JSONDecoder().decode(FridgeLedger.self, from: data) == ledger)
    }
}

struct ProRuleTests {
    @Test func firstRunIsATrialOfTheFullSize() {
        #expect(ProRules.dishLimit(isPro: false, runsCompleted: 0) == ProRules.proDishLimit)
        #expect(ProRules.dishLimit(isPro: false, runsCompleted: 1) == ProRules.freeDishLimit)
        #expect(ProRules.dishLimit(isPro: true, runsCompleted: 5) == ProRules.proDishLimit)
    }

    @Test func proRecipesNeedPro() {
        let free = recipe("free", [step(1, hands: true)])
        let pro = recipe("pro", [step(1, hands: true)], pro: true)
        #expect(ProRules.canUse(free, isPro: false))
        #expect(!ProRules.canUse(pro, isPro: false))
        #expect(ProRules.canUse(pro, isPro: true))
    }

    @Test func ghostNeedsABestAndProOrATrial() {
        #expect(!ProRules.canUseGhost(isPro: true, hasBest: false, trialsLeft: 1))
        #expect(ProRules.canUseGhost(isPro: false, hasBest: true, trialsLeft: 1))
        #expect(!ProRules.canUseGhost(isPro: false, hasBest: true, trialsLeft: 0))
        #expect(ProRules.canUseGhost(isPro: true, hasBest: true, trialsLeft: 0))
    }

    @Test func freeHistoryShowsTheNewestFive() {
        let records = (0..<8).map { record(seconds: 100 + $0, daysAgo: $0) }
        let free = ProRules.visibleHistory(records, isPro: false)
        #expect(free.count == ProRules.freeHistory)
        #expect(free.first?.seconds == 100)
        #expect(ProRules.visibleHistory(records, isPro: true).count == 8)
    }
}

private func record(_ ids: [String] = ["a", "b"], seconds: Int, daysAgo: Int = 0, par: Int = 1000) -> RunRecord {
    RunRecord(recipeIDs: ids, names: ids, date: day(2026, 11, 20).addingTimeInterval(-Double(daysAgo) * 86_400),
              seconds: seconds, parSeconds: par, sequentialSeconds: par * 2, parallelRate: 50, splits: [], burners: 2)
}

struct RouteTests {
    // A: 切る 10 → 煮る 20（待つ・コンロ）→ 仕上げ 5。B: 切る 10 → 漬ける 30（待つ）
    let a = recipe("a", [step(10, hands: true), step(20, hands: false, .burner), step(5, hands: true)])
    let b = recipe("b", [step(10, hands: true), step(30, hands: false)])

    @Test func routeIsOrderedByWhenYouPress() {
        let route = RunMath.route(Scheduler.plan([a, b]))
        #expect(route.count == 5)
        let checkpoints = route.map(\.checkpointMinutes)
        #expect(checkpoints == checkpoints.sorted())
        // 同じ品の工程は、いつも前から順に押す
        for r in [a, b] {
            let mine = route.filter { $0.planned.recipeID == r.id }.map(\.planned.stepIndex)
            #expect(mine == Array(0..<r.steps.count))
        }
    }

    @Test func aWaitIsPressedWhenItStartsAndAHandStepWhenItEnds() {
        let route = RunMath.route(Scheduler.plan([a]))
        #expect(route.map(\.checkpointMinutes) == [10, 10, 35])
        #expect(route.map(\.isWait) == [false, true, false])
    }

    @Test(arguments: RecipeBook.presets)
    func everyPresetMakesAConsistentRoute(preset: Preset) {
        let plan = Scheduler.plan(preset.recipeIDs.compactMap(RecipeBook.recipe))
        let route = RunMath.route(plan)
        #expect(route.count == plan.steps.count)
        for id in preset.recipeIDs {
            let mine = route.filter { $0.planned.recipeID == id }.map(\.planned.stepIndex)
            #expect(mine == mine.sorted(), "\(preset.id) の \(id) の工程の順が逆になる")
        }
    }

    @Test func finishWaitsForTheLastSimmer() {
        let route = RunMath.route(Scheduler.plan([a, b]))
        #expect(RunMath.finishSeconds(route: route, taps: [600, 600]) == nil)
        let taps = route.map { $0.checkpointMinutes * 60 }
        let finish = RunMath.finishSeconds(route: route, taps: taps)
        #expect(finish == Scheduler.plan([a, b]).totalMinutes * 60)
    }

    @Test func runningListsOnlyUnfinishedWaits() {
        let route = RunMath.route(Scheduler.plan([a]))
        #expect(RunMath.running(route: route, taps: [600, 600], now: 700).map(\.id) == ["a#1"])
        #expect(RunMath.running(route: route, taps: [600, 600], now: 1_800).isEmpty)
        #expect(RunMath.running(route: route, taps: [600], now: 700).isEmpty)
    }
}

struct RunScoreTests {
    @Test(arguments: [(850, Rank.s), (900, .s), (1_000, .a), (1_100, .b), (1_300, .c), (2_000, .d)])
    func rankFollowsTheRatioToThePar(seconds: Int, rank: Rank) {
        #expect(RunMath.rank(seconds: seconds, par: 1_000) == rank)
    }

    @Test func speedupIsRoundedToOneDecimal() {
        #expect(RunMath.speedup(seconds: 1_000, sequentialSeconds: 2_400) == 2.4)
        #expect(RunMath.speedup(seconds: 0, sequentialSeconds: 2_400) == 0)
    }

    @Test func parallelRateCountsTimeWithTwoThingsGoing() {
        // 0〜100 は 1 つ、50〜100 は 2 つ → 50%
        #expect(RunMath.parallelRate([Span(start: 0, end: 100), Span(start: 50, end: 150)], total: 100) == 50)
        #expect(RunMath.parallelRate([Span(start: 0, end: 100)], total: 100) == 0)
        #expect(RunMath.parallelRate([], total: 0) == 0)
    }

    @Test func spansTurnTapsIntoHandsAndWaits() {
        let a = recipe("a", [step(10, hands: true), step(20, hands: false, .burner), step(5, hands: true)])
        let route = RunMath.route(Scheduler.plan([a]))
        let spans = RunMath.spans(route: route, taps: [550, 560, 1_900])
        #expect(spans == [Span(start: 0, end: 550), Span(start: 560, end: 1_760), Span(start: 560, end: 1_900)])
    }

    @Test func splitAndGhostDeltas() {
        let a = recipe("a", [step(10, hands: true), step(20, hands: false, .burner)])
        let route = RunMath.route(Scheduler.plan([a]))
        #expect(RunMath.splitDelta(route: route, taps: [540], index: 0) == -60)
        #expect(RunMath.splitDelta(route: route, taps: [540], index: 1) == nil)
        let best = RunRecord(recipeIDs: ["a"], names: ["a"], date: day(2026, 11, 1), seconds: 1_700, parSeconds: 1_800,
                             sequentialSeconds: 1_800, parallelRate: 0, splits: [560, 570], burners: 2)
        #expect(RunMath.ghostDelta(best: best, taps: [540]) == -20)
        #expect(RunMath.ghostDelta(best: nil, taps: [540]) == nil)
        #expect(RunMath.ghostDelta(best: best, taps: []) == nil)
    }

    @Test func personalBestIsPerCourse() {
        let first = record(["a", "b"], seconds: 1_000, daysAgo: 3)
        let slower = record(["b", "a"], seconds: 1_100, daysAgo: 2)
        let faster = record(["a", "b"], seconds: 900, daysAgo: 1)
        let other = record(["c"], seconds: 2_000, daysAgo: 0)
        let all = [first, slower, faster, other]
        #expect(RunMath.isPersonalBest(first, in: all))
        #expect(!RunMath.isPersonalBest(slower, in: all))
        #expect(RunMath.isPersonalBest(faster, in: all))
        #expect(RunMath.isPersonalBest(other, in: all))
        #expect(RunMath.best(all, courseKey: RunMath.courseKey(["b", "a"]))?.seconds == 900)
    }

    @Test func clearStreakSkipsRunsStillBeingEatenAndStopsAtWaste() {
        let r = (0..<4).map { record(seconds: 100, daysAgo: $0) }
        let status: [UUID: EatStatus] = [r[0].id: .eating, r[1].id: .cleared, r[2].id: .cleared, r[3].id: .spoiled]
        #expect(RunMath.clearStreak(r) { status[$0.id]! } == 2)
    }

    @Test func eatingEverythingClearsTheRunAndWasteSpoilsIt() {
        var ledger = FridgeLedger()
        let run = UUID()
        let dish = recipe("x", [step(1, hands: true)])
        ledger.put([dish, dish], on: day(2026, 11, 1), calendar: tokyo, runID: run)
        #expect(ledger.status(ofRun: run) == .eating)
        ledger.eatAll(ledger.items[0].id, on: day(2026, 11, 2), calendar: tokyo)
        #expect(ledger.status(ofRun: run) == .eating)
        var spoiled = ledger
        ledger.eatAll(ledger.items[0].id, on: day(2026, 11, 2), calendar: tokyo)
        #expect(ledger.status(ofRun: run) == .cleared)
        spoiled.discard(spoiled.items[0].id, on: day(2026, 11, 3), calendar: tokyo)
        #expect(spoiled.status(ofRun: run) == .spoiled)
    }

    @Test func weeklyChallengeIsAFreePresetAndChangesByWeek() {
        let one = WeeklyChallenge.preset(for: day(2026, 11, 9), calendar: tokyo)
        let next = WeeklyChallenge.preset(for: day(2026, 11, 16), calendar: tokyo)
        #expect(!one.isPro && !next.isPro)
        #expect(one.id != next.id)
        #expect(WeeklyChallenge.preset(for: day(2026, 11, 10), calendar: tokyo).id == one.id)
    }
}

struct LookTests {
    @Test func everyCategoryHasItsOwnVessel() {
        let vessels = RecipeCategory.allCases.map(\.vessel)
        #expect(Set(vessels).count == RecipeCategory.allCases.count)
    }

    @Test func dishesInACategoryAreNotAllDrawnTheSame() {
        for category in RecipeCategory.allCases {
            let looks = RecipeBook.all.filter { $0.category == category }.map(\.topping)
            if looks.count >= 4 { #expect(Set(looks).count >= 3, "\(category) の器の絵が見分けにくい") }
        }
    }

    @Test func lanesNeverHoldOverlappingBlocks() {
        for preset in RecipeBook.presets {
            for lane in TimelineLayout.lanes(Scheduler.plan(preset.recipeIDs.compactMap(RecipeBook.recipe))) {
                for (x, y) in zip(lane.steps, lane.steps.dropFirst()) {
                    #expect(x.end <= y.start, "\(preset.id) の \(lane.kind.label) で帯が重なる")
                }
            }
        }
    }

    @Test(arguments: [(25, 5), (60, 10), (140, 20)])
    func ticksStayReadable(total: Int, tick: Int) {
        #expect(TimelineLayout.tick(total: total) == tick)
    }

    @Test func clockTexts() {
        #expect(Clock.text(2_538) == "42:18")
        #expect(Clock.text(3_725) == "1:02:05")
        #expect(Clock.delta(-96) == "−1:36")
        #expect(Clock.delta(45) == "+0:45")
    }
}

struct ComboAndNoteTests {
    @Test func comboCountsTrailingOnTimeTaps() {
        let a = recipe("a", [step(10, hands: true), step(5, hands: true), step(5, hands: true)])
        let route = RunMath.route(Scheduler.plan([a]))   // 目安 600・900・1200 秒
        #expect(RunMath.combo(route: route, taps: []) == 0)
        #expect(RunMath.combo(route: route, taps: [590, 880]) == 2)
        #expect(RunMath.combo(route: route, taps: [590, 880, 1_260]) == 0)   // 遅れると途切れる
        #expect(RunMath.combo(route: route, taps: [700, 880, 1_190]) == 2)
    }

    @Test func eveningNoteFiresAtSixAndNamesTodaysDish() {
        let morning = tokyo.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let night = tokyo.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 20))!
        #expect(tokyo.component(.hour, from: EveningNote.nextFire(after: morning, calendar: tokyo)) == 18)
        #expect(tokyo.component(.day, from: EveningNote.nextFire(after: morning, calendar: tokyo)) == 9)
        #expect(tokyo.component(.day, from: EveningNote.nextFire(after: night, calendar: tokyo)) == 10)

        var ledger = FridgeLedger()
        #expect(EveningNote.body(ledger: ledger, on: night, calendar: tokyo) == nil)
        let short = Recipe(id: "s", name: "浅漬け", category: .pickle, portions: 2, keepsDays: 1, freezable: false, isPro: false,
                           ingredients: [], steps: [])
        let long = Recipe(id: "l", name: "ピクルス", category: .pickle, portions: 2, keepsDays: 7, freezable: false, isPro: false,
                          ingredients: [], steps: [])
        ledger.put([long], on: day(2026, 11, 9), calendar: tokyo)
        #expect(EveningNote.body(ledger: ledger, on: night, calendar: tokyo) == nil)
        ledger.put([short], on: day(2026, 11, 9), calendar: tokyo)
        #expect(EveningNote.body(ledger: ledger, on: night, calendar: tokyo) == "浅漬けを、今日食べきりたい日です。")
    }
}
