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
    @Test func firstPlanIsATrialOfTheFullSize() {
        #expect(ProRules.dishLimit(isPro: false, plansCompleted: 0) == ProRules.proDishLimit)
        #expect(ProRules.dishLimit(isPro: false, plansCompleted: 1) == ProRules.freeDishLimit)
        #expect(ProRules.dishLimit(isPro: true, plansCompleted: 5) == ProRules.proDishLimit)
    }

    @Test func proRecipesNeedPro() {
        let free = recipe("free", [step(1, hands: true)])
        let pro = recipe("pro", [step(1, hands: true)], pro: true)
        #expect(ProRules.canUse(free, isPro: false))
        #expect(!ProRules.canUse(pro, isPro: false))
        #expect(ProRules.canUse(pro, isPro: true))
    }
}

struct CookProgressTests {
    @Test func aStartedSimmerRunsUntilTheNextStepIsDone() {
        let a = recipe("a", [step(10, hands: true), step(20, hands: false, .burner), step(5, hands: true)])
        let plan = Scheduler.plan([a])
        #expect(CookProgress.running(plan: plan, cooked: ["a#0"]).isEmpty)
        #expect(CookProgress.running(plan: plan, cooked: ["a#0", "a#1"]).map(\.id) == ["a#1"])
        #expect(CookProgress.running(plan: plan, cooked: ["a#0", "a#1", "a#2"]).isEmpty)
        #expect(CookProgress.isFinished(plan: plan, cooked: ["a#0", "a#1", "a#2"]))
    }
}
