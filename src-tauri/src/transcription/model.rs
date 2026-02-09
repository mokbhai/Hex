/// Transcription model types
#[derive(Debug, Clone, Copy)]
pub enum ModelType {
    Tiny,
    Base,
    Small,
    Medium,
    Large,
}

/// Transcription model
pub struct Model {
    pub model_type: ModelType,
}
