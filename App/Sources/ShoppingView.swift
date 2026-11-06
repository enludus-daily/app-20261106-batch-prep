import SwiftUI

/// 買い物リスト：同じ食材をまとめて、売り場ごとに。買ったものに印をつける
struct ShoppingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var tick = 0

    var body: some View {
        let groups = ShoppingList.build(model.selectedRecipes)
        let all = groups.flatMap(\.items).filter { $0.aisle != .season }
        let bought = all.filter { model.shoppingChecked.contains($0.id) }.count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom) {
                        Heading(kicker: "Shopping list", title: "買うもの \(all.count) 点")
                        Text("\(bought) / \(all.count)").font(.system(.subheadline, design: .serif)).monospacedDigit()
                            .foregroundStyle(Palette.mintDeep).contentTransition(.numericText())
                    }
                    if groups.isEmpty {
                        EmptyNote(title: "まだ空です", message: "段取りに品を選ぶと、材料がここにまとまります。", action: "閉じる") { dismiss() }
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.aisle.label).smallLabel().padding(.bottom, 6)
                            ForEach(group.items) { item in
                                row(item, isSeasoning: group.aisle == .season)
                                Rectangle().fill(Palette.line).frame(height: 0.6)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() }.tint(Palette.mintDeep) }
            }
        }
        .sensoryFeedback(trigger: tick) { _, _ in model.hapticsOn ? .selection : nil }
    }

    private func row(_ item: ShoppingItem, isSeasoning: Bool) -> some View {
        let checked = model.shoppingChecked.contains(item.id)
        return Button {
            tick += 1
            withAnimation(.easeOut(duration: 0.2)) {
                if checked { _ = model.shoppingChecked.remove(item.id) } else { _ = model.shoppingChecked.insert(item.id) }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? Palette.mintDeep : Palette.line)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(Typo.body).foregroundStyle(checked ? Palette.sub : Palette.ink)
                        .strikethrough(checked, color: Palette.sub)
                    Text(item.usedIn.joined(separator: "・")).font(Typo.label).foregroundStyle(Palette.sub).lineLimit(1)
                }
                Spacer()
                Text(item.amount == 0 ? "適量" : item.amountText)
                    .font(.system(.footnote, design: .serif)).monospacedDigit()
                    .foregroundStyle(isSeasoning ? Palette.sub : Palette.ink)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name) \(item.amountText)\(checked ? "、買った" : "")")
    }
}
