import AppKit
import SwiftUI

enum AppDesign {
    static let cardRadius: CGFloat = 0
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let inputBackground = Color(nsColor: .textBackgroundColor)
    static let accent = Color(red: 0.03, green: 0.49, blue: 0.52)
    static let muted = Color.primary.opacity(0.58)
    static let hairline = Color.primary.opacity(0.10)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .fill(AppDesign.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }
}

struct AppBrandIcon: View {
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let imageURL = Bundle.module.url(forResource: "PyCalIcon", withExtension: "png"),
               let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(AppDesign.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.6)
        }
    }
}

struct AppIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    var tint: Color = .secondary
    var isProminent = false

    init(
        systemName: String,
        help: String,
        tint: Color = .secondary,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.tint = tint
        self.isProminent = isProminent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isProminent ? AppDesign.accent : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct SidebarItemButton: View {
    let item: ToolboxItem
    let isSelected: Bool
    let showsSettings: Bool
    let settingsAction: (() -> Void)?
    let action: () -> Void

    init(
        item: ToolboxItem,
        isSelected: Bool,
        showsSettings: Bool = false,
        settingsAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.showsSettings = showsSettings
        self.settingsAction = settingsAction
        self.action = action
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 11) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                        Text(item.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.primary.opacity(0.62) : AppDesign.muted)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? Color.primary : AppDesign.muted)
            }
            .buttonStyle(.plain)

            if showsSettings {
                AppIconButton(systemName: "gearshape", help: "计算器设置") {
                    if let settingsAction {
                        settingsAction()
                    } else {
                        NotificationCenter.default.post(name: .showCalculatorSettings, object: nil)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? AppDesign.accent.opacity(0.13) : Color.clear)
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(AppDesign.accent)
                    .frame(width: 3, height: 24)
                    .offset(x: 1)
            }
        }
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
