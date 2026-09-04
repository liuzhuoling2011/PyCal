#if os(macOS)
import AppKit
#endif
import SwiftUI

#if os(macOS)
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
#endif

@main
struct PyCalApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(PyCalAppDelegate.self) private var appDelegate
    #endif
    @StateObject private var calculatorStore = CalculatorStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(calculatorStore)
                .preferredColorScheme(.light)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 720)
        .windowStyle(.hiddenTitleBar)
        #endif
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

private enum CompactTab: Hashable {
    case calculator
    case timeConverter
    case settings
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var calculatorStore: CalculatorStore
    @State private var selection: ToolboxItem = .calculator
    @State private var compactTab: CompactTab = .calculator
    @State private var showingSettings = false

    private var isCompact: Bool { AppLayout.isCompact(sizeClass) }

    var body: some View {
        Group {
            if isCompact {
                compactShell
            } else {
                regularShell
            }
        }
        .background(AppDesign.canvas)
        .preferredColorScheme(.light)
        .overlay {
            if showingSettings, !isCompact {
                SettingsModal {
                    showingSettings = false
                }
                .environmentObject(calculatorStore)
            }
        }
        .animation(.easeOut(duration: 0.16), value: showingSettings)
        .macOSExitCommand {
            if showingSettings { showingSettings = false }
        }
    }

    private var compactShell: some View {
        TabView(selection: $compactTab) {
            CalculatorView()
                .tabItem {
                    Label(ToolboxItem.calculator.title, systemImage: ToolboxItem.calculator.symbol)
                }
                .tag(CompactTab.calculator)

            TimeConverterView()
                .tabItem {
                    Label(ToolboxItem.timeConverter.title, systemImage: ToolboxItem.timeConverter.symbol)
                }
                .tag(CompactTab.timeConverter)

            NavigationStack {
                SettingsPage()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(CompactTab.settings)
        }
        .tint(AppDesign.ink)
    }

    private var regularShell: some View {
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
        #if os(macOS)
        .padding(.top, 42)
        #else
        .padding(.top, 16)
        #endif
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
