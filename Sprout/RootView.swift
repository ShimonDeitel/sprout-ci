import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @AppStorage("sprout.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var selection: Tab = .tonight

    enum Tab: Hashable { case tonight, library, settings }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        TabView(selection: $selection) {
            TonightView()
                .tabItem { Label("Tonight", systemImage: "moon.stars.fill") }
                .tag(Tab.tonight)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(.sproutAccent)
        .preferredColorScheme(theme.colorScheme)
        #if DEBUG
        .onAppear {
            switch ProcessInfo.processInfo.environment["SPROUT_SCREEN"] {
            case "library": selection = .library
            case "settings": selection = .settings
            default: break
            }
        }
        #endif
    }
}
