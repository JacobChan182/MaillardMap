import SwiftUI
import UIKit

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Installs a non-blocking tap recognizer on the hosting window.
/// This catches taps that SwiftUI gestures miss (sheets, safe-area insets, UIKit-backed search bars, maps, etc.).
private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    final class WindowObserverView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WindowObserverView {
        let view = WindowObserverView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowChange = { window in
            context.coordinator.install(in: window)
        }
        return view
    }

    func updateUIView(_ view: WindowObserverView, context: Context) {
        view.onWindowChange = { window in
            context.coordinator.install(in: window)
        }
        DispatchQueue.main.async {
            context.coordinator.install(in: view.window)
        }
    }

    static func dismantleUIView(_: WindowObserverView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var tapRecognizer: UITapGestureRecognizer?

        func install(in window: UIWindow?) {
            guard let window else { return }
            guard self.window !== window else { return }
            uninstall()

            let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self

            window.addGestureRecognizer(tap)
            self.window = window
            tapRecognizer = tap
        }

        func uninstall() {
            if let tapRecognizer, let window {
                window.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            window = nil
        }

        @objc private func onTap() {
            dismissKeyboard()
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UISearchBar {
                    return false
                }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// Non-blocking global keyboard dismiss on background taps.
private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            KeyboardDismissTapInstaller()
                .frame(width: 0, height: 0)
        }
    }
}

/// Adds a global keyboard toolbar with a trailing Done button.
private struct KeyboardDoneToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbarModifier())
    }
}
