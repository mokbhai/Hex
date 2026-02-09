// Settings persistence module
// Handles app settings storage using Tauri store plugin

pub mod settings;
pub mod history;

pub use settings::Settings;
pub use history::History;
