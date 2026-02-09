use cpal::{traits::StreamTrait, Stream};
use std::sync::{Arc, Mutex};

/// Audio recorder that captures microphone input
pub struct Recorder {
    stream: Arc<Mutex<Option<Stream>>>,
}

impl Recorder {
    pub fn new() -> Self {
        Self {
            stream: Arc::new(Mutex::new(None)),
        }
    }
}

impl Default for Recorder {
    fn default() -> Self {
        Self::new()
    }
}
