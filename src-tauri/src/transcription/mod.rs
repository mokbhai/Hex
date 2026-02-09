// Speech-to-text transcription module
// Handles model loading, audio transcription, and language detection

pub mod engine;
pub mod model;

pub use engine::TranscriptionEngine;
pub use model::{Model, ModelType};
