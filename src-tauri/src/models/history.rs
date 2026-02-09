use serde::{Deserialize, Serialize};

/// History entry model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: String,
    pub text: String,
    pub timestamp: i64,
}
