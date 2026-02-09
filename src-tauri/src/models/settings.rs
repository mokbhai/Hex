use serde::{Deserialize, Serialize};

/// Application settings model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub recording_hotkey: String,
    pub language: String,
}
