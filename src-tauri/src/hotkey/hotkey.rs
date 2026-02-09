/// Global hotkey manager
pub struct HotkeyManager;

impl HotkeyManager {
    pub fn new() -> Self {
        Self
    }
}

impl Default for HotkeyManager {
    fn default() -> Self {
        Self::new()
    }
}
