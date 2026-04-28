import SwiftUI
import UIKit

/// Non-blocking global keyboard dismiss on background taps.
private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            },
            including: .subviews
        )
    }
}

/// Adds a global keyboard toolbar with a trailing Done button.
private struct KeyboardDoneToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
