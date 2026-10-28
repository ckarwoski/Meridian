import SwiftUI

@main
struct MeridianApp: App {
    @State private var store = PlannerStore()
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = true

    var body: some Scene {
        Window("Meridian", id: PlannerView.windowID) {
            PlannerView()
                .frame(minWidth: 900, minHeight: 420)
                .environment(store)
                .task { await store.fillMissingCoordinates() }
        }
        .defaultSize(width: 1180, height: 640)
        .commands { PlannerCommands(store: store) }

        // The fastest way in: one click from anywhere.
        MenuBarExtra("Meridian", systemImage: "globe.americas", isInserted: $showInMenuBar) {
            PlannerView(inMenuBar: true)
                .frame(width: 1060, height: 620)
                .environment(store)
                .task { await store.fillMissingCoordinates() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

enum SettingsKey {
    static let use24Hour = "use24Hour"
    static let lookaheadDays = "lookaheadDays"
    static let showInMenuBar = "showInMenuBar"
    static let showDaylight = "showDaylight"
}

struct PlannerCommands: Commands {
    let store: PlannerStore

    var body: some Commands {
        CommandMenu("Go") {
            Button("Previous Day") { store.shift(days: -1) }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next Day") { store.shift(days: 1) }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Previous Week") { store.shift(days: -7) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            Button("Next Week") { store.shift(days: 7) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            Divider()
            Button("Today") { store.showToday() }
                .keyboardShortcut("t", modifiers: .command)
        }
    }
}
