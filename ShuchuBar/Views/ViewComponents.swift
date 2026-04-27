import Foundation
import SwiftUI

extension View {
    /// Apply flexible button sizing for segmented pickers on macOS 26+
    @ViewBuilder
    func applyButtonSizingFlexible() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonSizing(.flexible)
        } else {
            self
        }
    }

    /// Frame with maxWidth infinity and leading alignment
    func frameInfinityLeading() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
    }
}

func clampedNumberFormatter(min: Int, max: Int) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.minimum = NSNumber(value: min)
    formatter.maximum = NSNumber(value: max)
    formatter.generatesDecimalNumbers = false
    formatter.maximumFractionDigits = 0
    return formatter
}

// Adaptive UI size for different macOS versions
func uiSize(_ base: CGFloat, macOS26: CGFloat) -> CGFloat {
    if #available(macOS 26, *) { return macOS26 }
    return base
}

// Adaptive UI sizes for different macOS versions
enum UISizes {
    // Size for icon action buttons (pause, skip)
    static var actionButtonSize: CGFloat {
        uiSize(28, macOS26: 32)
    }

    // Height for small action buttons (+1, +5)
    static var smallActionButtonHeight: CGFloat {
        uiSize(20, macOS26: 22)
    }

    // Font size for action button icons
    static var actionFontSize: CGFloat {
        uiSize(20, macOS26: 22)
    }

    // Font size for small action button text (+1, +5)
    static var smallActionFontSize: CGFloat {
        uiSize(10, macOS26: 11)
    }
}

protocol DropdownDescribable: RawRepresentable where RawValue == String { }

struct EnumSegmentedPicker<E: CaseIterable & Hashable & DropdownDescribable>: View where E.RawValue == String, E.AllCases: RandomAccessCollection {
    @Binding var value: E

    var body: some View {
        Picker("", selection: $value) {
            ForEach(E.allCases, id: \.self) { option in
                Text(option.description)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .applyButtonSizingFlexible()
    }
}

extension DropdownDescribable {
    var description: String {
        switch self.rawValue {
        case "running": return NSLocalizedString("SettingsView.timer.show.active.label",
                                                 comment: "Show timer active label")
        case "always": return NSLocalizedString("SettingsView.timer.show.always.label",
                                                comment: "Show timer always label")
        case "clock": return "Clock"
        case "words": return "Words"
        default: return self.rawValue.capitalized
        }
    }
}

private struct IconButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: UISizes.actionFontSize))
            .accentColor(Color.white)
            .buttonStyle(.plain)
            .frame(width: UISizes.actionButtonSize, height: UISizes.actionButtonSize)
    }
}

extension View {
    func iconButtonStyle() -> some View {
        modifier(IconButtonStyle())
    }
}
