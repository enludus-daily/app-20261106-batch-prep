import Foundation
@preconcurrency import UserNotifications

// ローカル通知（端末の中だけ。サーバーなし）。
// - ラン中：仕掛けた待つ工程が終わる時刻に「〇〇：煮る が終わりました」（画面を消していても気づける）
// - 夕方 18 時：今日食べきりたい品があるときだけ、その品の名前で 1 回

enum ReminderStatus: Equatable, Sendable { case unknown, allowed, denied }

@MainActor
enum Reminders {
    static let dailyID = "daily.eat"

    static func status() async -> ReminderStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        default: return .unknown
        }
    }

    static func request() async -> ReminderStatus {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        return granted ? .allowed : await status()
    }

    static func schedule(id: String, title: String, body: String, at date: Date, now: Date = Date()) {
        let interval = date.timeIntervalSince(now)
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(_ ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func waitID(_ step: RouteStep) -> String { "wait." + step.id }
}

/// 夕方の通知の中身（画面から切り離してテストする）
enum EveningNote {
    static let hour = 18

    /// 次に知らせる時刻（今日の 18 時を過ぎていれば明日の 18 時）
    static func nextFire(after now: Date, calendar: Calendar) -> Date {
        let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        return today > now ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    /// その日に食べきりたい品（あと 1 日・今日まで・すぎた）。なければ nil（知らせない）
    static func body(ledger: FridgeLedger, on day: Date, calendar: Calendar) -> String? {
        let urgent = ledger.sorted(today: day, calendar: calendar).filter {
            !$0.isSample && ledger.freshness(of: $0, today: day, calendar: calendar).level >= 1
        }
        guard let first = urgent.first else { return nil }
        let rest = urgent.count - 1
        return rest > 0 ? "\(first.name)ほか \(rest) 品を、今日食べきりたい日です。" : "\(first.name)を、今日食べきりたい日です。"
    }
}
