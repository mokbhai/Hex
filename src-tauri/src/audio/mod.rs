// Audio recording module
// Handles microphone input, audio stream capture, and WAV format conversion

pub mod recorder;
pub mod device;

pub use recorder::Recorder;
pub use device::{list_devices, AudioDevice};
