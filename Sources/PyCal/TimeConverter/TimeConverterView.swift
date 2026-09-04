import SwiftUI

struct TimeConverterView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var store = TimeConverterStore()

    private var isCompact: Bool { AppLayout.isCompact(sizeClass) }
    private var gutter: CGFloat { AppLayout.gutter(sizeClass) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isCompact {
                    UnitSegment(store: store)
                    Spacer(minLength: 8)
                    TimezonePicker(store: store)
                } else {
                    Spacer()
                    UnitSegment(store: store)
                    TimezonePicker(store: store)
                }
            }
            .padding(.horizontal, gutter)
            .padding(.top, isCompact ? 12 : 16)
            .padding(.bottom, 4)

            if isCompact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DateColumn(store: store)
                        Rectangle()
                            .fill(AppDesign.hairline)
                            .frame(height: 1)
                            .padding(.horizontal, gutter)
                            .padding(.vertical, 8)
                        TimestampColumn(store: store)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    DateColumn(store: store)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle()
                        .fill(AppDesign.hairline)
                        .frame(width: 1)
                        .padding(.vertical, 8)
                    TimestampColumn(store: store)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            LiveTimestampBar(store: store)
        }
        .background(AppDesign.canvas)
        .onAppear {
            store.syncDateInput()
            store.convertDateToTimestamp()
        }
    }
}

private struct UnitSegment: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TimestampUnit.allCases) { unit in
                Button(unit.symbol) {
                    store.unit = unit
                    store.convertDateToTimestamp()
                    if !store.timestampInput.isEmpty { store.convertTimestampToDate() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(store.unit == unit ? AppDesign.ink : AppDesign.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    if store.unit == unit {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppDesign.paper)
                    }
                }
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TimezonePicker: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        Menu {
            ForEach(TimeConverterStore.commonTimezones, id: \.0) { timezone in
                Button {
                    store.setTimezone(timezone.0)
                } label: {
                    if store.timezoneIdentifier == timezone.0 {
                        Label(timezone.1, systemImage: "checkmark")
                    } else {
                        Text(timezone.1)
                    }
                }
            }
            Divider()
            Button("跟随系统（\(TimeZone.current.identifier)）") {
                store.setTimezone(TimeZone.current.identifier)
            }
        } label: {
            HStack(spacing: 6) {
                Text(timezoneLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 12.5))
            .foregroundStyle(AppDesign.muted)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .fixedSize()
    }

    private var timezoneLabel: String {
        TimeConverterStore.commonTimezones.first(where: { $0.0 == store.timezoneIdentifier })?.1
            ?? store.timezoneIdentifier
    }
}

private struct DateColumn: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("日期")
                .font(.system(size: 11))
                .foregroundStyle(AppDesign.muted)
                .padding(.bottom, 10)
            TextField("YYYY-MM-DD HH:mm:ss", text: $store.dateInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(AppDesign.ink)
                .numericKeyboard()
                .onChange(of: store.dateInput) { _, _ in store.convertDateInput(showError: false) }
                .onSubmit { store.convertDateInput() }
                .padding(.bottom, 11)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppDesign.composerBorder).frame(height: 1)
                }
            Text(store.dateOutput.isEmpty ? " " : store.dateOutput)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(AppDesign.ink)
                .textSelection(.enabled)
                .padding(.top, 18)
            HStack(spacing: 12) {
                QuietTextButton(title: "此刻") { store.setDateToNow() }
                QuietTextButton(title: "零点") { setStartOfDay() }
                QuietTextButton(title: "每日末") { store.setDateToEndOfDay() }
                if !store.dateOutput.isEmpty {
                    QuietTextButton(title: "复制") { Clipboard.copy(store.dateOutput) }
                }
            }
            .padding(.top, 10)
            if let error = store.dateError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).padding(.top, 8)
            }
        }
        .padding(.horizontal, AppLayout.gutter(sizeClass))
        .padding(.top, 18)
    }

    private func setStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = store.timezone
        store.dateValue = calendar.startOfDay(for: store.dateValue)
        store.syncDateInput()
        store.convertDateToTimestamp()
    }
}

private struct TimestampColumn: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Unix 时间戳")
                .font(.system(size: 11))
                .foregroundStyle(AppDesign.muted)
                .padding(.bottom, 10)
            TextField("输入时间戳", text: $store.timestampInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(AppDesign.ink)
                .numericKeyboard()
                .onChange(of: store.timestampInput) { _, _ in store.convertTimestampToDate(showError: false) }
                .onSubmit { store.convertTimestampToDate() }
                .padding(.bottom, 11)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppDesign.composerBorder).frame(height: 1)
                }
            Text(store.timestampOutput.isEmpty ? " " : store.timestampOutput)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(AppDesign.ink)
                .textSelection(.enabled)
                .padding(.top, 18)
            HStack(spacing: 12) {
                QuietTextButton(title: "使用当前") {
                    store.timestampInput = store.currentTimestamp
                    store.convertTimestampToDate()
                }
                if !store.timestampOutput.isEmpty {
                    QuietTextButton(title: "复制") { Clipboard.copy(store.timestampOutput) }
                }
            }
            .padding(.top, 10)
            if let error = store.timestampError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).padding(.top, 8)
            }
        }
        .padding(.horizontal, AppLayout.gutter(sizeClass))
        .padding(.top, 18)
    }
}

private struct LiveTimestampBar: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var store: TimeConverterStore

    private var isCompact: Bool { AppLayout.isCompact(sizeClass) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: store.unit == .nanoseconds ? 0.1 : 1)) { context in
            let liveDate = store.isPaused ? store.pausedDate : context.date
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            liveIndicator
                            Text(store.timestampString(for: liveDate))
                                .font(.system(size: 13.5, design: .monospaced))
                                .foregroundStyle(AppDesign.ink)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        HStack(spacing: 16) {
                            QuietTextButton(title: "复制") {
                                Clipboard.copy(store.timestampString(for: liveDate))
                            }
                            QuietTextButton(title: store.isPaused ? "继续" : "暂停") {
                                store.togglePause()
                            }
                            QuietTextButton(title: "重置") {
                                store.resetLiveClock()
                            }
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        liveIndicator
                        Text(store.timestampString(for: liveDate))
                            .font(.system(size: 13.5, design: .monospaced))
                            .foregroundStyle(AppDesign.ink)
                            .textSelection(.enabled)
                        Spacer()
                        QuietTextButton(title: "复制") {
                            Clipboard.copy(store.timestampString(for: liveDate))
                        }
                        QuietTextButton(title: store.isPaused ? "继续" : "暂停") {
                            store.togglePause()
                        }
                        QuietTextButton(title: "重置") {
                            store.resetLiveClock()
                        }
                    }
                }
            }
            .padding(.horizontal, AppLayout.gutter(sizeClass))
            .padding(.vertical, isCompact ? 12 : 14)
            .overlay(alignment: .top) {
                Rectangle().fill(AppDesign.hairline).frame(height: 1)
            }
        }
    }

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.isPaused ? Color.orange : AppDesign.preview)
                .frame(width: 6, height: 6)
            Text(store.isPaused ? "已暂停" : "实时")
                .font(.system(size: 12.5))
                .foregroundStyle(AppDesign.muted)
        }
    }
}
