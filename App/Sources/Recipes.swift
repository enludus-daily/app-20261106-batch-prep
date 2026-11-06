import Foundation

// 作り置きのレシピ帳の型と、手で書いたデータ（RecipeData.swift）の読み込み。
// 画面から切り離してテストできる形にしている。

/// 工程に使う道具。段取りの計算では「同時に使える数」が決まった資源になる。
enum Device: String, Codable, Sendable, CaseIterable {
    case none, burner, micro, oven

    var label: String {
        switch self {
        case .none: "なし"
        case .burner: "コンロ"
        case .micro: "レンジ"
        case .oven: "グリル"
        }
    }
}

struct RecipeStep: Hashable, Codable, Sendable {
    let text: String
    let minutes: Int
    /// true なら手が離せない（切る・炒める）。false なら待つだけ（煮る・漬ける・レンジ）
    let hands: Bool
    let device: Device
}

enum Aisle: String, Codable, Sendable, CaseIterable {
    case veg, meat, egg, dry, season

    var label: String {
        switch self {
        case .veg: "野菜・きのこ"
        case .meat: "肉・魚・加工品"
        case .egg: "卵・豆腐・大豆"
        case .dry: "乾物・缶詰"
        case .season: "調味料（家にあるか確認）"
        }
    }
}

struct Ingredient: Hashable, Codable, Sendable {
    let name: String
    let amount: Double
    let unit: String
    let aisle: Aisle
}

enum RecipeCategory: String, Codable, Sendable, CaseIterable {
    case main, side, pickle, soup, bento, freeze

    var label: String {
        switch self {
        case .main: "主菜"
        case .side: "副菜"
        case .pickle: "漬け・あえ"
        case .soup: "汁の素"
        case .bento: "お弁当"
        case .freeze: "冷凍の素"
        }
    }
}

struct Recipe: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: RecipeCategory
    /// 何食分になるか（容器の中身の目盛り）
    let portions: Int
    /// 冷蔵で食べきるめやすの日数
    let keepsDays: Int
    let freezable: Bool
    let isPro: Bool
    let ingredients: [Ingredient]
    let steps: [RecipeStep]

    var totalMinutes: Int { steps.reduce(0) { $0 + $1.minutes } }
    var handsMinutes: Int { steps.filter(\.hands).reduce(0) { $0 + $1.minutes } }
}

enum RecipeParseError: Error, Equatable {
    case badLine(Int, String)
}

/// 1 行 1 項目の書式を読む。
/// `R|id|名前|分類|何食|日持ち|冷凍(0/1)|Pro(0/1)`
/// `I|材料|量|単位|売り場`（量 0 は「適量」）
/// `S|工程|分|h(手)/w(待つ)|道具(-/burner/micro/oven)`
enum RecipeParser {
    static func parse(_ text: String) throws -> [Recipe] {
        var recipes: [Recipe] = []
        var head: [String]?
        var ingredients: [Ingredient] = []
        var steps: [RecipeStep] = []

        func flush() throws {
            guard let h = head else { return }
            guard let category = RecipeCategory(rawValue: h[3]),
                  let portions = Int(h[4]), let keeps = Int(h[5]) else {
                throw RecipeParseError.badLine(0, h.joined(separator: "|"))
            }
            recipes.append(Recipe(id: h[1], name: h[2], category: category, portions: portions,
                                  keepsDays: keeps, freezable: h[6] == "1", isPro: h[7] == "1",
                                  ingredients: ingredients, steps: steps))
            head = nil; ingredients = []; steps = []
        }

        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let f = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            switch f.first {
            case "R" where f.count == 8:
                try flush()
                head = f
            case "I" where f.count == 5 && head != nil:
                guard let amount = Double(f[2]), let aisle = Aisle(rawValue: f[4]) else {
                    throw RecipeParseError.badLine(index + 1, line)
                }
                ingredients.append(Ingredient(name: f[1], amount: amount, unit: f[3], aisle: aisle))
            case "S" where f.count == 5 && head != nil:
                guard let minutes = Int(f[2]), minutes > 0, f[3] == "h" || f[3] == "w" else {
                    throw RecipeParseError.badLine(index + 1, line)
                }
                let device: Device = f[4] == "-" ? .none : (Device(rawValue: f[4]) ?? .none)
                steps.append(RecipeStep(text: f[1], minutes: minutes, hands: f[3] == "h", device: device))
            default:
                throw RecipeParseError.badLine(index + 1, line)
            }
        }
        try flush()
        return recipes
    }
}

enum RecipeBook {
    /// 手で書いたデータ。読めなければテストで落ちる（ここでは空にして画面を落とさない）
    static let all: [Recipe] = (try? RecipeParser.parse(RecipeData.text)) ?? []

    static func recipe(_ id: String) -> Recipe? { all.first { $0.id == id } }

    /// おすすめの組み合わせ（空の段取りの画面で出す）
    static let presets: [Preset] = [
        Preset(id: "first", title: "はじめての3品", note: "煮物・炒め物・漬け物を1つずつ", recipeIDs: ["nikujaga", "kinpira", "kyuri-asazuke"], isPro: false),
        Preset(id: "weekday", title: "平日の主菜と副菜", note: "鶏の主菜に、日持ちする副菜を2つ", recipeIDs: ["tori-chashu", "hijiki", "ninjin-rapee"], isPro: false),
        Preset(id: "veggie", title: "野菜を食べきる3品", note: "冷蔵庫の野菜を使いきる", recipeIDs: ["kabocha-ni", "nasu-bitashi", "kinoko-marine"], isPro: false),
        Preset(id: "quick", title: "40分で3品", note: "レンジと炒め物で手早く", recipeIDs: ["ninjin-rapee", "broccoli-goma", "piman-okaka"], isPro: false),
        Preset(id: "bento", title: "お弁当の1週間", note: "そぼろ・つくね・彩りの副菜", recipeIDs: ["soboro", "tsukune", "ingen-goma", "iri-tamago", "tamagoyaki"], isPro: true),
        Preset(id: "freezer", title: "冷凍庫を育てる", note: "1か月もつ素をまとめて", recipeIDs: ["keema", "meat-sauce", "kinoko-mix", "sake-flake"], isPro: true),
        Preset(id: "soup", title: "汁ものを毎日", note: "みそ玉と具をつくっておく", recipeIDs: ["miso-dama", "tonjiru-no-moto", "minestrone-moto"], isPro: true),
        Preset(id: "feast", title: "週末のごちそう6品", note: "コンロ2口を使いきる", recipeIDs: ["kakuni", "chicken-tomato", "okara", "pickles", "komatsuna", "daigaku-imo"], isPro: true),
    ]
}

struct Preset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let note: String
    let recipeIDs: [String]
    let isPro: Bool
}
