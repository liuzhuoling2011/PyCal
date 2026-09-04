import AppKit
import SwiftUI

enum AppDesign {
    static let canvas = Color(red: 246 / 255, green: 246 / 255, blue: 244 / 255)
    static let rail = Color(red: 236 / 255, green: 236 / 255, blue: 232 / 255)
    static let paper = Color.white
    static let ink = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)
    static let secondary = Color(red: 58 / 255, green: 58 / 255, blue: 56 / 255)
    static let muted = Color(red: 138 / 255, green: 138 / 255, blue: 134 / 255)
    static let faint = Color(red: 180 / 255, green: 180 / 255, blue: 174 / 255)
    static let preview = Color(red: 61 / 255, green: 107 / 255, blue: 102 / 255)
    static let hairline = Color.black.opacity(0.07)
    static let rowHover = Color.black.opacity(0.035)
    static let iconSelected = Color.black.opacity(0.08)
    static let composerBorder = Color.black.opacity(0.10)

    static let railWidth: CGFloat = 176
    static let inspectorWidth: CGFloat = 232
    static let iconSize: CGFloat = 30
    static let iconRadius: CGFloat = 8
    static let inspectorRadius: CGFloat = 12
    static let composerRadius: CGFloat = 16
}

struct AppIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    var tint: Color = AppDesign.muted
    var isProminent = false
    var showsHoverCaption = false
    @State private var isHovering = false

    init(
        systemName: String,
        help: String,
        tint: Color = AppDesign.muted,
        isProminent: Bool = false,
        showsHoverCaption: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.tint = tint
        self.isProminent = isProminent
        self.showsHoverCaption = showsHoverCaption
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isProminent ? Color.white : tint)
                .frame(width: 24, height: 24)
                .background {
                    if isProminent {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppDesign.ink)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovering = $0 }
        .overlay(alignment: .top) {
            if showsHoverCaption, isHovering {
                Text(help)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppDesign.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppDesign.paper, in: Capsule())
                    .overlay {
                        Capsule().stroke(AppDesign.hairline, lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                    .fixedSize()
                    .offset(y: -22)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(isHovering ? 20 : 0)
    }
}

struct RailItemButton: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 20, alignment: .center)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected || isHovering ? AppDesign.ink : AppDesign.muted)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppDesign.iconSelected : (isHovering ? AppDesign.rowHover : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .help(title)
        .onHover { isHovering = $0 }
    }
}

final class NonMovingView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NonMovingView {
        NonMovingView()
    }

    func updateNSView(_ nsView: NonMovingView, context: Context) {}
}

final class NonMovingHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct WindowDragDisabled<Content: View>: NSViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NonMovingHostingView<Content> {
        NonMovingHostingView(rootView: content)
    }

    func updateNSView(_ nsView: NonMovingHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

struct QuietTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(AppDesign.muted)
    }
}

enum Clipboard {
    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

enum NumberDisplay {
    static func string(_ value: Double, grouping: Bool = true) -> String {
        guard value.isFinite else {
            if value.isNaN { return "nan" }
            return value.sign == .minus ? "-inf" : "inf"
        }

        if value == 0 { return "0" }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 12
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1

        let magnitude = abs(value)
        if magnitude >= 1e15 || magnitude < 1e-9 {
            return String(format: "%.10g", value)
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
