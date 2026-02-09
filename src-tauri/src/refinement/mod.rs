// Text refinement module
// Handles LLM-powered text improvement using OpenAI API

pub mod refinement;
pub mod prompt;

pub use refinement::TextRefiner;
pub use prompt::PromptTemplate;
