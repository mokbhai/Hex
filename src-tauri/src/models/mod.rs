// Data models module
// Shared data structures for the application

pub mod transcription;
pub mod settings;
pub mod history;

pub use transcription::Transcription;
pub use settings::AppSettings;
pub use history::HistoryEntry;
