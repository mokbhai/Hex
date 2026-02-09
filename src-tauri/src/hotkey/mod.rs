// Global hotkey module
// Handles system-wide keyboard shortcuts

pub mod hotkey;
pub mod press_and_hold;
pub mod double_tap;

pub use hotkey::HotkeyManager;
pub use press_and_hold::PressAndHold;
pub use double_tap::DoubleTap;
