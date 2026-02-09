# Tauri + React + Typescript

This template should help get you started developing with Tauri, React and Typescript in Vite.

## Recommended IDE Setup

- [VS Code](https://code.visualstudio.com/) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)

## Project Structure

```
src-tauri/
├── src/
│   ├── main.rs          # Entry point
│   ├── lib.rs           # Library exports and Tauri setup
│   ├── audio/           # Audio recording module
│   ├── transcription/   # Speech-to-text module
│   ├── clipboard/       # Text injection module
│   ├── hotkey/          # Global hotkey module
│   ├── refinement/      # LLM text refinement module
│   ├── store/           # Settings persistence
│   └── models/          # Data models
src/
├── components/          # React components
├── hooks/               # Custom React hooks
├── stores/              # Zustand stores
├── types/               # TypeScript types
└── utils/               # Utility functions
```
