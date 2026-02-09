/// Prompt template for LLM refinement
pub struct PromptTemplate {
    pub system_prompt: String,
}

impl PromptTemplate {
    pub fn new() -> Self {
        Self {
            system_prompt: String::from("Improve the text for clarity and grammar."),
        }
    }
}
