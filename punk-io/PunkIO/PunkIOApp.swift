import SwiftUI

@main
struct PunkIOApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "flame.fill")
                    Text("Viral")
                }
                .tag(0)

            DiscoverView()
                .tabItem {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text("Descobrir")
                }
                .tag(1)

            SavedView()
                .tabItem {
                    Image(systemName: "bookmark.fill")
                    Text("Salvos")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Config")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var autoRefresh = true
    @State private var selectedPlatforms: Set<PlatformSource> = Set(PlatformSource.allCases)
    @State private var refreshInterval = 60.0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Punk.io")
                                .font(.title)
                                .fontWeight(.black)
                            Text("Sistema de Ideias Infinitas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("v1.0.0")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Notificações") {
                    Toggle("Alertas de conteúdo viral", isOn: $notificationsEnabled)
                    Toggle("Atualização automática", isOn: $autoRefresh)

                    if autoRefresh {
                        VStack(alignment: .leading) {
                            Text("Intervalo: \(Int(refreshInterval))s")
                                .font(.caption)
                            Slider(value: $refreshInterval, in: 30...300, step: 30)
                                .tint(.purple)
                        }
                    }
                }

                Section("Plataformas") {
                    ForEach(PlatformSource.allCases) { platform in
                        Toggle(isOn: Binding(
                            get: { selectedPlatforms.contains(platform) },
                            set: { isOn in
                                if isOn {
                                    selectedPlatforms.insert(platform)
                                } else {
                                    selectedPlatforms.remove(platform)
                                }
                            }
                        )) {
                            Label(platform.rawValue, systemImage: platform.icon)
                        }
                    }
                }

                Section("Sobre") {
                    Link(destination: URL(string: "https://example.com")!) {
                        Label("Website", systemImage: "globe")
                    }
                    Label("Feito com SwiftUI", systemImage: "swift")
                }
            }
            .navigationTitle("Configurações")
            .tint(.purple)
        }
    }
}
