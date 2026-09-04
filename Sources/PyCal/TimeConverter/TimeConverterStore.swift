import Foundation
import SwiftUI

enum TimestampUnit: String, CaseIterable, Identifiable {
    case nanoseconds = "纳秒"
    case milliseconds = "毫秒"
    case seconds = "秒"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .nanoseconds: "ns"
        case .milliseconds: "ms"
        case .seconds: "s"
        }
    }

    var multiplier: Double {
        switch self {
        case .nanoseconds: 1_000_000_000
        case .milliseconds: 1_000
        case .seconds: 1
        }
    }
}

@MainActor
final class TimeConverterStore: ObservableObject {
    @Published var unit: TimestampUnit = .seconds
    @Published var timezoneIdentifier = TimeZone.current.identifier
    @Published var dateValue = Date()
    @Published var dateInput = TimeConverterStore.dateFormatter(timezone: .current).string(from: Date())
    @Published private(set) var dateOutput = ""
    @Published var timestampInput = ""
    @Published private(set) var timestampOutput = ""
    @Published var dateError: String?
    @Published var timestampError: String?
    @Published var isPaused = false
    @Published var pausedDate = Date()

    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    var currentDate: Date {
        isPaused ? pausedDate : Date()
    }

    var currentTimestamp: String {
        timestampString(for: currentDate)
    }

    var currentDateString: String {
        Self.dateFormatter(timezone: timezone).string(from: currentDate)
    }

    func convertDateToTimestamp() {
        let timestamp = dateValue.timeIntervalSince1970 * unit.multiplier
        guard timestamp.isFinite else {
            dateError = "日期超出时间戳可表示范围"
            dateOutput = ""
            return
        }
        dateOutput = timestampString(from: timestamp)
        dateError = nil
    }

    func convertTimestampToDate(showError: Bool = true) {
        let clean = timestampInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")) else {
            timestampError = showError ? "请输入有效的 \(unit.symbol) 时间戳" : nil
            timestampOutput = ""
            return
        }
        let seconds = NSDecimalNumber(decimal: decimal).doubleValue / unit.multiplier
        guard seconds.isFinite, abs(seconds) <= 253_402_300_799 else {
            timestampError = showError ? "时间戳超出日期范围" : nil
            timestampOutput = ""
            return
        }
        let date = Date(timeIntervalSince1970: seconds)
        timestampOutput = Self.dateFormatter(timezone: timezone).string(from: date)
        timestampError = nil
    }

    func setDateToNow() {
        dateValue = Date()
        syncDateInput()
        convertDateToTimestamp()
    }

    func setDateToEpoch() {
        dateValue = Date(timeIntervalSince1970: 0)
        syncDateInput()
        convertDateToTimestamp()
    }

    func setDateToEndOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        var localCalendar = calendar
        localCalendar.timeZone = timezone
        dateValue = localCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: dateValue) ?? dateValue
        syncDateInput()
        convertDateToTimestamp()
    }

    func convertDateInput(showError: Bool = true) {
        let clean = dateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let date = Self.parseDate(clean, timezone: timezone) else {
            dateError = showError ? "日期格式应为 YYYY-MM-DD HH:mm:ss（也支持斜杠）" : nil
            dateOutput = ""
            return
        }
        dateValue = date
        convertDateToTimestamp()
    }

    func syncDateInput() {
        dateInput = Self.dateFormatter(timezone: timezone).string(from: dateValue)
    }

    func setTimezone(_ identifier: String) {
        timezoneIdentifier = identifier
        syncDateInput()
        convertDateToTimestamp()
        if !timestampInput.isEmpty { convertTimestampToDate() }
    }

    func copyCurrentTimestamp() {
        Clipboard.copy(currentTimestamp)
    }

    func togglePause() {
        if isPaused {
            isPaused = false
        } else {
            pausedDate = Date()
            isPaused = true
        }
    }

    func resetLiveClock() {
        pausedDate = Date()
        isPaused = false
    }

    func timestampString(for date: Date) -> String {
        timestampString(from: date.timeIntervalSince1970 * unit.multiplier)
    }

    private func timestampString(from value: Double) -> String {
        switch unit {
        case .seconds:
            return String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
                .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        case .milliseconds, .nanoseconds:
            return String(Int64(value.rounded(.towardZero)))
        }
    }

    static func dateFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    static func inputDateFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = dateFormatter(timezone: timezone)
        formatter.isLenient = false
        return formatter
    }

    static func parseDate(_ value: String, timezone: TimeZone) -> Date? {
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm"] {
            let formatter = inputDateFormatter(timezone: timezone)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

extension TimeConverterStore {
    static let commonTimezones: [(String, String)] = [
        ("Asia/Shanghai", "中国标准时间 (UTC+8)"),
        ("Asia/Tokyo", "日本标准时间 (UTC+9)"),
        ("Asia/Singapore", "新加坡时间 (UTC+8)"),
        ("Asia/Kolkata", "印度标准时间 (UTC+5:30)"),
        ("Europe/London", "英国时间"),
        ("Europe/Berlin", "中欧时间"),
        ("America/Los_Angeles", "太平洋时间"),
        ("America/New_York", "东部时间"),
        ("UTC", "协调世界时 (UTC)")
    ]
}
