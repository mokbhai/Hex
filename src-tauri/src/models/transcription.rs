use serde::{Deserialize, Serialize};

/// Transcription data model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transcription {
    pub id: String,
    pub text: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}
