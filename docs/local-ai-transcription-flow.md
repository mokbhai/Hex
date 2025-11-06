
# Local AI Transcription Flow in Hex

This document provides a high-level overview of how Hex downloads, manages, and utilizes local AI models for voice transcription. The core technologies used are **WhisperKit** for the transcription engine and **The Composable Architecture (TCA)** for managing state and side effects.

## Core Components

The system is divided into three main parts:

1.  **Model Management UI (`ModelDownloadFeature.swift`)**: The SwiftUI view and TCA logic located in the app's settings, allowing users to view, download, and delete transcription models.
2.  **Transcription Client (`TranscriptionClient.swift`)**: A dedicated client that acts as a wrapper around `WhisperKit`. It is responsible for all interactions with the model, including downloading, loading into memory, and running the transcription.
3.  **Transcription Process (`TranscriptionFeature.swift`)**: The TCA feature that orchestrates the entire process from listening for a hotkey press to recording audio and ultimately triggering the transcription.

---

## 1. Model Management and Downloading

The user manages models through the settings view, which is powered by `ModelDownloadFeature`.

### Files Involved:

-   `Hex/Features/Settings/ModelDownloadFeature.swift`: Contains the UI and business logic for the model management screen.
-   `Hex/Clients/TranscriptionClient.swift`: Handles the actual downloading and file management.
-   `Hex/Resources/Data/models.json`: A static JSON file containing a curated list of recommended models with user-friendly metadata (display name, size, performance).

### High-Level Flow:

1.  **Fetching Models**:
    -   When the settings view appears, `ModelDownloadFeature` sends a `.fetchModels` action.
    -   The reducer for this action calls two functions on the `TranscriptionClient`:
        -   `getAvailableModels()`: Fetches a complete list of all compatible model variants from the `argmaxinc/whisperkit-coreml` Hugging Face repository.
        -   `isModelDownloaded(modelName)`: For each available model, it checks if the model's files already exist on the user's disk.
    -   The feature also loads the curated list from `models.json` to present a user-friendly view.

2.  **Downloading a Model**:
    -   The user selects a model and clicks "Download". This sends the `.downloadSelectedModel` action.
    -   The reducer calls `transcription.downloadModel(modelName)`.
    -   Inside `TranscriptionClient`, the `downloadAndLoadModel()` function is executed. It uses `WhisperKit.download()` to fetch the model files from Hugging Face.
    -   The model is saved to a dedicated folder within the app's Application Support directory (e.g., `~/Library/Application Support/com.kitlangton.Hex/models/`).
    -   Download progress is streamed back to the `ModelDownloadFeature` to update the UI with a progress bar.

3.  **Deleting a Model**:
    -   If the user deletes a model, the `.deleteSelectedModel` action calls `transcription.deleteModel(modelName)`, which removes the corresponding model directory from the Application Support folder.

---

## 2. Voice Transcription Process

The end-to-end process of recording and transcribing is managed by `TranscriptionFeature`.

### Files Involved:

-   `Hex/Features/Transcription/TranscriptionFeature.swift`: Orchestrates the recording and transcription flow based on hotkey events.
-   `Hex/Clients/TranscriptionClient.swift`: Performs the transcription using the selected model.
-   `Hex/Models/HexSettings.swift`: A shared model that stores the user's preferences, including the `selectedModel`.

### High-Level Flow:

1.  **Initiating Recording**:
    -   `TranscriptionFeature` continuously monitors for keyboard events via a `HotKeyProcessor`.
    -   When the user presses the designated hotkey, a `.hotKeyPressed` action is sent, which, after a short delay, triggers a `.startRecording` action.

2.  **Recording Audio**:
    -   The app begins recording audio using a `RecordingClient`.
    -   When the user releases the hotkey, a `.hotKeyReleased` action is sent, which in turn triggers `.stopRecording`.

3.  **Performing Transcription**:
    -   The `stopRecording` logic is where the transcription is initiated.
    -   It retrieves the name of the user's chosen model from the shared `HexSettings`.
    -   It calls `transcription.transcribe(audioURL, modelName)`.
    -   Inside `TranscriptionClient`, the following happens:
        -   It checks if the requested `modelName` is already loaded into the active `WhisperKit` instance.
        -   If not, it calls its internal `downloadAndLoadModel()` function. This function first ensures the model is downloaded (if it wasn't already) and then loads it into memory. This step is what users perceive as "prewarming" or "loading the model."
        -   Once the model is loaded, `WhisperKit` processes the audio file and returns the transcribed text as a string.

4.  **Finalizing**:
    -   The resulting text is sent back to `TranscriptionFeature` in a `.transcriptionResult` action.
    -   The feature then uses a `PasteboardClient` to paste the text into the active application and saves the transcript to history if the user has enabled it.
