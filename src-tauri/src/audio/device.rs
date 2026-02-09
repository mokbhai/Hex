use cpal::traits::{DeviceTrait, HostTrait};

/// Audio device information
#[derive(Debug, Clone)]
pub struct AudioDevice {
    pub name: String,
    pub id: String,
}

/// List all available input audio devices
pub fn list_devices() -> Result<Vec<AudioDevice>, String> {
    let host = cpal::default_host();
    let devices = host.input_devices()
        .map_err(|e| format!("Failed to get input devices: {}", e))?;

    let result: Vec<AudioDevice> = devices
        .filter_map(|d| {
            d.name().ok().map(|name| AudioDevice {
                name,
                id: uuid::Uuid::new_v4().to_string(),
            })
        })
        .collect();

    Ok(result)
}
