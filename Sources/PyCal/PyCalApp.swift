import AppKit
import SwiftUI

final class PyCalAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` starts the executable from a terminal. Explicitly make
        // the SwiftUI window the active key window so keyboard input goes to
        // its TextField instead of remaining with Terminal.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct PyCalApp: App {
    @NSApplicationDelegateAdaptor(PyCalAppDelegate.self) private var appDelegate
    @StateObject private var calculatorStore = CalculatorStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(calculatorStore)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1160, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建计算行") {
                    NotificationCenter.default.post(name: .focusCalculatorInput, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

enum ToolboxItem: String, CaseIterable, Identifiable {
    case calculator
    case timeConverter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calculator: "稿纸计算器"
        case .timeConverter: "时间转换"
        }
    }

    var subtitle: String {
        switch self {
        case .calculator: "Python 风格表达式"
        case .timeConverter: "时间戳与日期"
        }
    }

    var symbol: String {
        switch self {
        case .calculator: "plus.forwardslash.minus"
        case .timeConverter: "clock.arrow.2.circlepath"
        }
    }
}

struct AppShellView: View {
    @State private var selection: ToolboxItem? = .calculator

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 280)
        } detail: {
            Group {
                switch selection ?? .calculator {
                case .calculator:
                    CalculatorView()
                case .timeConverter:
                    TimeConverterView()
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct AppSidebar: View {
    @Binding var selection: ToolboxItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppBrandIcon(size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PyCal")
                        .font(.system(size: 16, weight: .semibold))
                    Text("原生小工具箱")
                        .font(.system(size: 11))
                        .foregroundStyle(AppDesign.muted)
                }
                Spacer()
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 19)

            Text("工具")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 23)
                .padding(.bottom, 8)

            VStack(spacing: 3) {
                ForEach(ToolboxItem.allCases) { item in
                    SidebarItemButton(
                        item: item,
                        isSelected: selection == item,
                        showsSettings: item == .calculator,
                        settingsAction: item == .calculator ? {
                            selection = .calculator
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .showCalculatorSettings, object: nil)
                            }
                        } : nil
                    ) {
                        selection = item
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 20)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                Text("数据仅保存在本机")
                    .font(.system(size: 11))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 15)
            .padding(.bottom, 16)
        }
        .background(AppDesign.sidebarBackground)
    }
}

extension Notification.Name {
    static let focusCalculatorInput = Notification.Name("focusCalculatorInput")
    static let showCalculatorSettings = Notification.Name("showCalculatorSettings")
}
