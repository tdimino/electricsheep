import SwiftUI

struct PreferencesView: View {
    @AppStorage("cacheSizeGB") private var cacheSizeGB: Double = 2.0
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("downloadOnMetered") private var downloadOnMetered: Bool = true

    @State private var showingResetConfirmation = false

    var body: some View {
        TabView {
            GeneralTab(
                cacheSizeGB: $cacheSizeGB,
                launchAtLogin: $launchAtLogin,
                downloadOnMetered: $downloadOnMetered,
                showingResetConfirmation: $showingResetConfirmation
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            HotkeysTab()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
        .alert("Reset Cache?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetCache()
            }
        } message: {
            Text("This will delete all downloaded sheep. They will be re-downloaded automatically.")
        }
    }

    private func resetCache() {
        let cacheManager = CacheManager.shared
        let fileManager = FileManager.default

        // Delete sheep directories
        try? fileManager.removeItem(at: cacheManager.freeSheepDirectory)
        try? fileManager.removeItem(at: cacheManager.goldSheepDirectory)

        // Recreate structure
        cacheManager.ensureDirectoryStructure()

        // Restart sync
        DownloadManager.shared.startSync()
    }
}

struct GeneralTab: View {
    @Binding var cacheSizeGB: Double
    @Binding var launchAtLogin: Bool
    @Binding var downloadOnMetered: Bool
    @Binding var showingResetConfirmation: Bool

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cache Size Limit:")
                        Spacer()
                        Text("\(Int(cacheSizeGB)) GB")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $cacheSizeGB, in: 1...20, step: 1)

                    HStack {
                        Text("Current usage:")
                        Spacer()
                        Text(formatBytes(CacheManager.shared.cacheSize))
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Download on Metered Networks", isOn: $downloadOnMetered)
            }

            Section {
                HStack {
                    Text("Sheep Count:")
                    Spacer()
                    Text("\(CacheManager.shared.sheepCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Cache Location:")
                    Spacer()
                    Text("~/Library/Application Support/ElectricSheep")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Section {
                Button("Reset Cache...") {
                    showingResetConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Use SMAppService on macOS 13+, ServiceManagement on older versions
        if #available(macOS 13.0, *) {
            // SMAppService.mainApp.register() / unregister()
            // Requires proper setup in Info.plist
        } else {
            // Legacy ServiceManagement approach
        }
    }
}

struct HotkeysTab: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Vote Up:")
                    Spacer()
                    Text("⌘ ↑")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                HStack {
                    Text("Vote Down:")
                    Spacer()
                    Text("⌘ ↓")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            } header: {
                Text("Voting Hotkeys")
            } footer: {
                Text("Press these keys while the screensaver is running to vote on the current sheep.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Text("Global hotkeys work when the screensaver is in fullscreen mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Electric Sheep Companion")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("Electric Sheep is a distributed computing project for animating and evolving fractal flames.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            Link("electricsheep.org", destination: URL(string: "https://electricsheep.org")!)
                .font(.caption)

            Spacer()

            Text("Created by Scott Draves")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    PreferencesView()
}
