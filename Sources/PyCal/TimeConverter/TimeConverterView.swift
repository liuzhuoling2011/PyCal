import SwiftUI

struct TimeConverterView: View {
    @StateObject private var store = TimeConverterStore()

    var body: some View {
        VStack(spacing: 0) {
            TimeConverterToolbar(store: store)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        DateToTimestampCard(store: store)
                            .frame(maxWidth: .infinity)
                        TimestampToDateCard(store: store)
                            .frame(maxWidth: .infinity)
                    }
                    LiveTimestampCard(store: store)
                }
                .frame(maxWidth: .infinity)
                .padding(0)
            }
            .background(AppDesign.pageBackground)
        }
        .background(AppDesign.pageBackground)
    }
}

private struct TimeConverterToolbar: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        HStack(spacing: 3) {
            Spacer()
            Picker("", selection: $store.unit) {
                ForEach(TimestampUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: store.unit) { _, _ in
                store.convertDateToTimestamp()
                if !store.timestampInput.isEmpty { store.convertTimestampToDate() }
            }
            TimezonePicker(store: store)
        }
        .padding(.horizontal, 28)
        .padding(.top, 31)
        .padding(.bottom, 9)
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
            HStack(spacing: 9) {
                Image(systemName: "globe.asia.australia")
                Text(timezoneLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .frame(width: 190, alignment: .leading)
        }
        .menuStyle(.borderedButton)
    }

    private var timezoneLabel: String {
        TimeConverterStore.commonTimezones.first(where: { $0.0 == store.timezoneIdentifier })?.1
            ?? store.timezoneIdentifier
    }
}

private struct DateToTimestampCard: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Label("日期 → 时间戳", systemImage: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text(store.timezone.abbreviation() ?? store.timezoneIdentifier)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppDesign.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppDesign.accent.opacity(0.10), in: Capsule())
                Spacer()
                Menu {
                    Button("此刻", systemImage: "clock") { store.setDateToNow() }
                    Button("零点", systemImage: "hourglass") {
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = store.timezone
                        store.dateValue = calendar.startOfDay(for: store.dateValue)
                        store.syncDateInput()
                        store.convertDateToTimestamp()
                    }
                    Button("每日末", systemImage: "hourglass.bottomhalf.fill") { store.setDateToEndOfDay() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
            }
            Text("日期时间")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("YYYY-MM-DD HH:mm:ss", text: $store.dateInput)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .onChange(of: store.dateInput) { _, _ in store.convertDateInput(showError: false) }
                .onSubmit { store.convertDateInput() }
                .padding(.horizontal, 12)
                .frame(height: 43)
                .background(AppDesign.inputBackground, in: Rectangle())
                .overlay {
                    Rectangle()
                        .stroke(AppDesign.hairline, lineWidth: 1)
                }
            ResultField(value: store.dateOutput.isEmpty ? "点击日期或输入后换算" : store.dateOutput, accent: AppDesign.accent) {
                Clipboard.copy(store.dateOutput)
            }
            if let error = store.dateError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
        .padding(18)
        .appCard()
        .onAppear {
            store.syncDateInput()
            store.convertDateToTimestamp()
        }
    }
}

private struct TimestampToDateCard: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Label("时间戳 → 日期", systemImage: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text(store.timezone.abbreviation() ?? store.timezoneIdentifier)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppDesign.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppDesign.accent.opacity(0.10), in: Capsule())
                Spacer()
                AppIconButton(systemName: "clock.arrow.circlepath", help: "使用当前时间戳") {
                    store.timestampInput = store.currentTimestamp
                    store.convertTimestampToDate()
                }
            }
            Text("Unix 时间戳（\(store.unit.symbol)）")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("输入时间戳", text: $store.timestampInput)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .onChange(of: store.timestampInput) { _, _ in store.convertTimestampToDate(showError: false) }
                .onSubmit { store.convertTimestampToDate() }
                .padding(.horizontal, 12)
                .frame(height: 43)
                .background(AppDesign.inputBackground, in: Rectangle())
                .overlay {
                    Rectangle()
                        .stroke(AppDesign.hairline, lineWidth: 1)
                }
            ResultField(value: store.timestampOutput.isEmpty ? "换算结果将在这里显示" : store.timestampOutput, accent: AppDesign.accent) {
                Clipboard.copy(store.timestampOutput)
            }
            if let error = store.timestampError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
        .padding(18)
        .appCard()
    }
}

private struct LiveTimestampCard: View {
    @ObservedObject var store: TimeConverterStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: store.unit == .nanoseconds ? 0.1 : 1)) { context in
            let liveDate = store.isPaused ? store.pausedDate : context.date
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    Label("当前时间戳", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(store.currentDateString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .center) {
                    Text(store.timestampString(for: liveDate))
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppDesign.accent)
                        .textSelection(.enabled)
                    Spacer()
                    AppIconButton(systemName: "doc.on.doc", help: "复制") {
                        Clipboard.copy(store.timestampString(for: liveDate))
                    }
                    AppIconButton(
                        systemName: store.isPaused ? "play.fill" : "pause.fill",
                        help: store.isPaused ? "继续" : "暂停",
                        tint: .white,
                        isProminent: true
                    ) {
                        store.togglePause()
                    }
                    AppIconButton(systemName: "arrow.counterclockwise", help: "重置") {
                        store.resetLiveClock()
                    }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isPaused ? .orange : AppDesign.accent)
                        .frame(width: 7, height: 7)
                    Text(store.isPaused ? "已暂停在当前时刻" : "实时更新中")
                        .font(.system(size: 11))
                        .foregroundStyle(AppDesign.muted)
                }
            }
            .padding(18)
            .appCard()
        }
    }
}

private struct ResultField: View {
    let value: String
    let accent: Color
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(value.hasPrefix("点击") || value.hasPrefix("换算") ? .secondary : accent)
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            if !value.hasPrefix("点击") && !value.hasPrefix("换算") {
                AppIconButton(systemName: "doc.on.doc", help: "复制", action: copy)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 43, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: Rectangle())
    }
}
