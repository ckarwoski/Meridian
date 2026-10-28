import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = Format.localePrefers24Hour
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = true
    @AppStorage(SettingsKey.showDaylight) private var showDaylight = true

    var body: some View {
        Form {
            Toggle("Use 24-hour time", isOn: $use24Hour)
            Toggle("Show daylight under each hour", isOn: $showDaylight)
            Toggle("Show in menu bar", isOn: $showInMenuBar)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }
}
