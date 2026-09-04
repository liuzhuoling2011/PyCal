import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppLayout {
    static func isCompact(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    static func gutter(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isCompact(sizeClass) ? 16 : 28
    }
}

enum Clipboard {
    static func copy(_ value: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }
}

#if os(macOS)
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
#else
struct WindowDragDisabled<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View { content }
}
#endif

extension View {
    @ViewBuilder
    func desktopSheetSize(width: CGFloat, height: CGFloat? = nil) -> some View {
        #if os(macOS)
        if let height {
            self.frame(width: width, height: height)
        } else {
            self.frame(width: width)
        }
        #else
        self.frame(maxWidth: .infinity)
        #endif
    }

    @ViewBuilder
    func formulaKeyboard() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numericKeyboard() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }

    @ViewBuilder
    func macOSExitCommand(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.onExitCommand(perform: action)
        #else
        self
        #endif
    }
}
