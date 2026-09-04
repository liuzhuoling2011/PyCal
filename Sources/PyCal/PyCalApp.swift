import AppKit
import SwiftUI

final class PyCalAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.windows.first?.isMovableByWindowBackground = true
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
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 720)
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
        case .calculator: "稿纸计算"
        case .timeConverter: "时间换算"
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
    @EnvironmentObject private var calculatorStore: CalculatorStore
    @State private var selection: ToolboxItem = .calculator
    @State private var showingSettings = false

    var body: some View {
        HStack(spacing: 0) {
            AppIconRail(selection: $selection, showingSettings: $showingSettings)
            Group {
                switch selection {
                case .calculator:
                    CalculatorView()
                case .timeConverter:
                    TimeConverterView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppDesign.canvas)
        }
        .background(AppDesign.canvas)
        .overlay {
            if showingSettings {
                SettingsModal {
                    showingSettings = false
                }
                .environmentObject(calculatorStore)
            }
        }
        .animation(.easeOut(duration: 0.16), value: showingSettings)
        .onExitCommand {
            if showingSettings { showingSettings = false }
        }
    }
}

private struct AppIconRail: View {
    @Binding var selection: ToolboxItem
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(ToolboxItem.allCases) { item in
                RailItemButton(
                    systemName: item.symbol,
                    title: item.title,
                    isSelected: selection == item
                ) {
                    selection = item
                }
            }
            Spacer(minLength: 12)
            RailItemButton(
                systemName: "gearshape",
                title: "设置",
                isSelected: showingSettings
            ) {
                showingSettings.toggle()
            }
        }
        .padding(.top, 42)
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        .frame(width: AppDesign.railWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppDesign.rail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppDesign.hairline)
                .frame(width: 1)
        }
    }
}

extension Notification.Name {
    static let focusCalculatorInput = Notification.Name("focusCalculatorInput")
}
