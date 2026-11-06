import Foundation

// 買い物リスト。選んだ品の材料を、同じ名前・同じ単位どうしで足して、売り場ごとにまとめる。

struct ShoppingItem: Identifiable, Hashable, Sendable {
    var id: String { name + "|" + unit }
    let name: String
    let amount: Double
    let unit: String
    let aisle: Aisle
    /// この材料を使う品の名前
    let usedIn: [String]

    var amountText: String { ShoppingList.format(amount) + unit }
}

struct ShoppingGroup: Identifiable, Hashable, Sendable {
    var id: Aisle { aisle }
    let aisle: Aisle
    let items: [ShoppingItem]
}

enum ShoppingList {
    static func build(_ recipes: [Recipe]) -> [ShoppingGroup] {
        var order: [String] = []
        var merged: [String: ShoppingItem] = [:]
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let key = ingredient.name + "|" + ingredient.unit
                if let old = merged[key] {
                    let used = old.usedIn.contains(recipe.name) ? old.usedIn : old.usedIn + [recipe.name]
                    merged[key] = ShoppingItem(name: old.name, amount: old.amount + ingredient.amount, unit: old.unit,
                                               aisle: old.aisle, usedIn: used)
                } else {
                    order.append(key)
                    merged[key] = ShoppingItem(name: ingredient.name, amount: ingredient.amount, unit: ingredient.unit,
                                               aisle: ingredient.aisle, usedIn: [recipe.name])
                }
            }
        }
        let items = order.compactMap { merged[$0] }
        var groups: [ShoppingGroup] = []
        for aisle in Aisle.allCases {
            let inSection = items.filter { $0.aisle == aisle }
            if !inSection.isEmpty { groups.append(ShoppingGroup(aisle: aisle, items: inSection)) }
        }
        return groups
    }

    /// 0.5 → 1/2、1.25 → 1と1/4、2 → 2、1.5 → 1と1/2。それ以外は小数 1 桁
    static func format(_ value: Double) -> String {
        let whole = Int(value.rounded(.down))
        let fraction = value - Double(whole)
        let names: [(Double, String)] = [(0.25, "1/4"), (0.5, "1/2"), (0.75, "3/4")]
        if abs(fraction) < 0.001 { return "\(whole)" }
        if let match = names.first(where: { abs($0.0 - fraction) < 0.001 }) {
            return whole == 0 ? match.1 : "\(whole)と\(match.1)"
        }
        return String(format: "%.1f", value)
    }
}
