fn main() {
    tauri_build::build()
}

// The tauri_build::build() function automatically handles:
// - Reading entitlements from the macOS bundle configuration in tauri.conf.json
// - Applying the correct entitlements during development and production builds
// - Setting up the Info.plist with the configured entries
