# Mobile Music Transcription App - User Guide

## Overview
The Autotab mobile app is a comprehensive music transcription tool built with Flutter that allows users to record audio and transcribe it into musical notation.

## App Structure

### Screens

#### 1. Home Screen (`lib/screens/home_screen.dart`)
- **Purpose**: Main landing page of the app
- **Features**:
  - Welcome message and app description
  - "Start Recording" button to navigate to the recording screen
  - "View Exports" button to navigate to the export screen
  - Clean, centered UI with music note icon

#### 2. Record Screen (`lib/screens/record_screen.dart`)
- **Purpose**: Record audio and configure recording settings
- **Features**:
  - BPM (Beats Per Minute) input field
  - Instrument selection dropdown (Guitar, Piano, Drums, Violin)
  - Record/Stop button with visual feedback
  - Recording status indicator (microphone icon changes color)
  - Edit button to review and edit transcriptions
  - Integration with AudioService for recording functionality

#### 3. Edit Screen (`lib/screens/edit_screen.dart`)
- **Purpose**: Edit transcribed musical notes
- **Features**:
  - Multi-line text editor for transcription
  - Save button to store the transcription
  - Integration with AppStateProvider to persist data

#### 4. Export Screen (`lib/screens/export_screen.dart`)
- **Purpose**: View and export saved transcriptions
- **Features**:
  - Export options (MIDI and Tabs)
  - List of all saved transcriptions
  - Delete functionality for individual transcriptions
  - Integration with AppStateProvider to display saved data

### Services

#### 1. Audio Service (`lib/services/audio_service.dart`)
- Handles audio recording and playback
- Manages microphone permissions
- Singleton pattern for consistent state

#### 2. App State Provider (`lib/services/app_state_provider.dart`)
- Manages application state using Provider pattern
- Stores transcriptions and settings
- Notifies listeners of state changes

#### 3. Pitch Detection Service (`lib/services/pitch_detection.dart`)
- Detects pitch using the Yin algorithm
- Validates pitch against instrument frequency ranges

#### 4. Note Segmentation Service (`lib/services/note_segmentation.dart`)
- Segments continuous audio into individual notes
- Extracts timing and frequency information

#### 5. Tab Generator Service (`lib/services/tab_generator.dart`)
- Converts transcriptions to guitar tabs
- Generates text notation

#### 6. MIDI Generator Service (`lib/services/midi_generator.dart`)
- Exports transcriptions as MIDI files

### Models

#### 1. Note (`lib/models/note.dart`)
- Represents a musical note with frequency, name, octave, timing, and confidence

#### 2. Transcription (`lib/models/transcription.dart`)
- Represents a complete transcription with metadata

#### 3. Settings (`lib/models/settings.dart`)
- Stores user preferences and configuration

## Navigation Flow

```
Home Screen
    ├─> Record Screen
    │       └─> Edit Screen
    │               └─> (Save & Return)
    └─> Export Screen
            └─> (View saved transcriptions)
```

## Key Features

1. **Multi-Platform Support**: Built with Flutter for iOS, Android, Web, Windows, macOS, and Linux
2. **State Management**: Uses Provider for efficient state management
3. **Audio Recording**: Integrated audio recording with permission handling
4. **Transcription Storage**: Persistent storage of transcriptions
5. **Export Options**: Multiple export formats (MIDI, Tabs)
6. **Instrument Support**: Guitar, Piano, Drums, and Violin

## Dependencies

- `flutter`: Core framework
- `flutter_sound`: Audio recording and playback
- `provider`: State management
- `permission_handler`: Audio permission management

## Getting Started

1. Install Flutter SDK
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to launch the app
4. Grant microphone permissions when prompted

## Testing

Run tests with:
```bash
flutter test
```

The test suite includes:
- App launch verification
- Navigation flow tests
- Widget interaction tests
