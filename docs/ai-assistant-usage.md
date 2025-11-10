# Hex AI Assistant - Feature Usage Guide

## Overview

Hex is a voice-activated AI assistant that integrates with your macOS system to provide intelligent, context-aware assistance. This guide covers all major features and how to use them effectively.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Voice System Control](#voice-system-control)
3. [Information Search](#information-search)
4. [Productivity Tools](#productivity-tools)
5. [AI Model Management](#ai-model-management)
6. [Advanced Settings](#advanced-settings)
7. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Activation

Hex activates through a customizable hotkey. By default, press and hold the hotkey to start recording voice commands.

**Steps:**
1. Open Hex application
2. System menu bar icon appears
3. Configure your preferred hotkey in Settings
4. Press and hold the hotkey to speak a command

### Configuration

First-time setup requires:
- **Select AI Model**: Choose from local Hugging Face models or configure API access
- **Search Provider**: Select web search backend (Google, Bing, or custom)
- **Hotkey**: Assign your preferred hotkey combination
- **Audio Settings**: Configure microphone and speaker preferences

### Voice Command Format

Commands are context-sensitive. Hex recognizes intents including:
- **System Control**: "Open Safari", "Close Finder", "Maximize window"
- **Search**: "Search for quantum computing", "Find Python documentation"
- **Productivity**: "Set a 5-minute timer", "Calculate 15% of 200", "Create a note about the meeting"
- **Information**: "What is the capital of France?", "Tell me about recent AI news"

---

## Voice System Control

### Application Management

| Intent | Examples |
|--------|----------|
| Open Application | "Open Safari", "Launch Xcode", "Start Calendar" |
| Close Application | "Close Chrome", "Quit Firefox", "Shut down Finder" |
| Switch Applications | "Switch to Mail", "Go to Messages", "Activate Terminal" |
| Minimize Window | "Minimize this window", "Hide Finder" |
| Maximize Window | "Maximize Safari", "Full screen this app" |
| Arrange Windows | "Tile windows", "Stack windows" |

### System Commands

| Intent | Examples |
|--------|----------|
| Volume Control | "Increase volume", "Mute", "Set volume to 80%" |
| Brightness | "Increase brightness", "Dim the screen" |
| Lock Screen | "Lock my computer", "Engage lock" |
| Sleep | "Put computer to sleep", "Sleep now" |

### Context-Aware Behavior

Hex remembers recent application contexts and can apply commands intelligently:
- "Open the last file I was working on"
- "Switch back to where I was before"
- "Close all tabs in the current browser"

---

## Information Search

### Web Search

Search the internet using your configured provider:

```
"Search for machine learning frameworks"
"Find restaurants near me"
"What are the latest news on AI?"
"Look up Python async documentation"
```

**Supported Providers:**
- **Google Search** (default, requires API key)
- **Bing Search** (requires API key)
- **Custom Provider** (use own endpoint)

### Local File Search

Search files on your machine:

```
"Find all PDFs in Downloads"
"Search for files named 'project'"
"Look for spreadsheets modified today"
```

### Result Handling

Results automatically:
- Format for readability
- Highlight key information
- Provide direct links
- Support opening in browser

**Workflow:**
1. Speak search query
2. Results display in notification window
3. Click result to open in browser
4. Return to Hex for next command

---

## Productivity Tools

### Timers

Create and manage countdown timers via voice:

```
"Set a 5-minute timer"
"Create a 30-second timer for the microwave"
"Start a 2-hour timer for the presentation"
```

**Timer Features:**
- Visual countdown
- Sound alert when complete
- Multiple simultaneous timers
- Pause/resume capability
- Persistent across app reopening

### Calculator

Perform arithmetic calculations naturally:

```
"What is 25 times 4?"
"Calculate 30% of 150"
"How much is 1000 divided by 8?"
"What's the square root of 256?"
```

**Supported Operations:**
- Basic math (addition, subtraction, multiplication, division)
- Percentages
- Powers and roots
- Decimal precision

### Notes

Create and manage notes efficiently:

```
"Create a note about the project meeting"
"Add to my ideas list: improve search latency"
"Note: follow up with Sarah on Tuesday"
```

**Note Features:**
- Voice creation and editing
- Tagging system for organization
- Search by tag or content
- Date-stamped for reference
- Persistent storage

### Todo Lists

Track tasks and maintain productivity:

```
"Add 'review pull requests' to my todos"
"Create a high-priority task to prepare presentation"
"Mark 'update documentation' as done"
```

**Todo Features:**
- Priority levels (low, medium, high)
- Completion tracking
- Due date support
- List organization
- Quick reminders

---

## AI Model Management

### Selecting Models

Hex supports multiple AI models:

**Local Models (via Hugging Face):**
- Mistral 7B (lightweight, fast)
- Llama 2 7B (balanced)
- Neural Chat 7B (optimized for chat)

**Remote Models (via API):**
- OpenAI GPT-4
- Anthropic Claude
- Custom endpoints

### Downloading Models

Models download automatically on selection. Track progress in the model manager:

1. Open Settings
2. Go to "AI Models"
3. Select desired model
4. Download automatically begins
5. View progress in notification

**Storage:** Models cache locally for offline capability (~5-15 GB depending on model).

### Model Performance

Choose based on your hardware:

| Model | Size | Speed | Quality | VRAM |
|-------|------|-------|---------|------|
| Mistral 7B | 14 GB | Very Fast | Good | 8 GB |
| Llama 2 7B | 13 GB | Fast | Good | 8 GB |
| Neural Chat 7B | 15 GB | Fast | Excellent | 8 GB |

---

## Advanced Settings

### Search Provider Configuration

Access Settings → Search Providers to:

1. **Choose Provider:**
   - Google Search (default)
   - Bing Search
   - Custom endpoint

2. **API Configuration:**
   - Enter API key
   - Configure endpoint (if custom)
   - Test connection

3. **Search Behavior:**
   - Result count preference
   - Language settings
   - Safe search toggle

### Voice Feedback

Customize audio responses:

1. **Text-to-Speech:**
   - Enable/disable voice responses
   - Choose voice (male, female, accent)
   - Adjust speech rate
   - Set volume level

2. **Audio Notifications:**
   - Sound effects for timer/alerts
   - Confirmation sounds
   - Error audio cues

### Hotkey Configuration

Set your preferred activation key:

1. Open Settings
2. Go to "Hotkeys"
3. Click "Record Hotkey"
4. Press your desired key combination
5. Save

**Recommendations:**
- Use modifier keys (Cmd, Option, Control)
- Avoid system-reserved hotkeys
- Choose something easy to remember

### Context Awareness

Hex learns your patterns:

1. **Automatic Learning:**
   - Tracks frequently used applications
   - Remembers recent search topics
   - Learns your preferred response style

2. **Manual Configuration:**
   - Set work/personal contexts
   - Configure time-based automation
   - Define custom triggers

### Workflow Automation

Create automated workflows based on triggers:

1. **Time-Based:**
   - "Every morning at 9 AM, read my calendar"
   - "On Fridays, remind me of pending tasks"

2. **Event-Based:**
   - "When I open Mail, check for urgent messages"
   - "When battery is low, find charging locations"

3. **Context-Based:**
   - "When I'm at work, show relevant messages"
   - "During meetings, suppress notifications"

---

## Troubleshooting

### Microphone Not Recognized

**Solution:**
1. Check System Preferences → Sound → Input
2. Select correct microphone
3. Test microphone in Hex settings
4. Grant microphone permissions if prompted

### Commands Not Recognized

**Check:**
- Microphone is working and positioned correctly
- You're speaking clearly at normal volume
- Language is set correctly in settings
- AI model is loaded and responsive

**Improve Recognition:**
- Use specific command phrasing from examples
- Avoid background noise
- Speak naturally without overdoing pronunciation

### Search Results Not Appearing

**Verify:**
- Internet connection is active
- Search provider API key is valid
- API quota hasn't been exceeded
- Provider URL is correct (for custom providers)

**Debug:**
- Check API key in Settings
- Test API connection
- Review error logs in help menu

### Slow Model Loading

**Optimize:**
- Close unnecessary applications
- Allow time for initial model load
- Check available disk space
- Restart Hex if performance degrades

### Audio Output Issues

**Troubleshoot:**
- Check System Preferences → Sound → Output
- Verify speaker connection
- Adjust volume in Hex settings
- Test audio in macOS System Preferences

### Persistent Problems

If issues continue:
1. Check Help → Logs for error details
2. Visit the Hex troubleshooting guide
3. Contact support with log files

---

## Best Practices

### Voice Command Tips

1. **Be Specific**: "Set a 5-minute timer" works better than "timer"
2. **Use Natural Language**: Speak as you normally would
3. **Wait for Confirmation**: Listen for acknowledgment before continuing
4. **Batch Commands**: Group related tasks when possible
5. **Leverage Context**: Hex remembers recent apps and searches

### Performance Optimization

1. **Manage Models**: Remove unused models to free space
2. **Clean Search History**: Regularly clear old searches
3. **Archive Notes**: Move old notes to avoid slowdowns
4. **Update Regularly**: Keep Hex and models current

### Privacy and Security

1. **Voice Data**: Audio deleted immediately after processing
2. **API Keys**: Store in system keychain
3. **Local Storage**: Encrypted by default
4. **Permissions**: Review app permissions in System Preferences

### Accessibility

Hex is designed for users of all abilities:
- Voice input for hands-free operation
- Adjustable text sizes
- Customizable audio feedback
- Keyboard navigation support

---

## Getting Help

- **In-App Help**: Press Cmd+? for keyboard shortcuts
- **Online Docs**: Visit hex.local for detailed documentation
- **Community**: Join our Discord for tips and tricks
- **Support**: Email support@hex.local

---

## Feature Roadmap

Planned features coming soon:
- Multi-language voice support
- Offline model improvements
- Calendar integration
- Email dictation
- Custom workflow builder UI

---

**Last Updated**: November 2024
**Version**: 1.0
