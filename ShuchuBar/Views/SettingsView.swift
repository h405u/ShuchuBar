import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                HStack {
                    Text("Menu Bar Time")
                        .frameInfinityLeading()
                    EnumSegmentedPicker(value: $timer.menuBarTimeStyle)
                }
                .onChange(of: timer.menuBarTimeStyle) { _ in
                    timer.updateDisplay()
                }

                HStack {
                    Text(NSLocalizedString("SettingsView.timer.show.label",
                                           comment: "Show timer label"))
                        .frameInfinityLeading()
                    EnumSegmentedPicker(value: $timer.showTimerMode)
                }
                .onChange(of: timer.showTimerMode) { _ in
                    timer.updateDisplay()
                }

                Toggle(isOn: $timer.player.soundEnabled) {
                    Text("Sound")
                        .frameInfinityLeading()
                }
                .toggleStyle(.switch)

                KeyboardShortcuts.Recorder(for: .focusSession) {
                    Text("Start / End Focus")
                        .frameInfinityLeading()
                }

                KeyboardShortcuts.Recorder(for: .endBreak) {
                    Text("End Break")
                        .frameInfinityLeading()
                }

                KeyboardShortcuts.Recorder(for: .awakenApp) {
                    Text("Open App")
                        .frameInfinityLeading()
                }

                Toggle(isOn: $launchAtLogin.isEnabled) {
                    Text(NSLocalizedString("SettingsView.app.launchAtLogin.label",
                                           comment: "Launch at login label"))
                        .frameInfinityLeading()
                }
                .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 2)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
