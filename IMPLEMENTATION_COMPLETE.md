# Autotab Implementation Documentation

## Overview
This document describes the complete implementation of the Autotab music transcription application.

## Architecture

### Models (`lib/models/`)

#### 1. **Note** (`note.dart`)
Represents a single musical note detected in audio.
- **Properties**: frequency, noteName, octave, startTime, endTime, confidence
- **Methods**: `toJson()`, `fromJson()` for serialization
- **Usage**: Core data structure used throughout the processing pipeline

#### 2. **AppSettings** (`settings.dart`)
Application-wide settings and preferences.
- **Properties**: selectedInstrument, bpm, noiseThreshold, uiPreferences
- **Methods**: `toJson()`, `fromJson()`, `defaultSettings()`
- **Usage**: Persisting user preferences

#### 3. **Transcription** (`transcription.dart`)
Complete transcription metadata and results.
- **Properties**: id, name, instrumentType, bpm, notes, metadata
- **Methods**: `toJson()`, `fromJson()`
- **Usage**: Storing and retrieving saved transcriptions

---

### Services (`lib/services/`)

#### 1. **AudioService** (`audio_service.dart`)
**Purpose**: Handles audio recording with real-time visualization  
**Dependencies**: `record` package, `permission_handler`

**Key Features**:
- Real-time audio recording using the `record` package (Windows-compatible)
- Live amplitude monitoring for visual feedback (100ms intervals)
- Platform-specific file path management
- Audio level streaming for UI visualization
- Microphone permission handling

**API**:
```dart
Future<void> initialize()
Future<void> startRecording()
Future<String?> stopRecording()
Stream<double> get audioLevelStream  // 0.0 to 1.0
bool get isRecording
```

#### 2. **PitchDetectionService** (`pitch_detection.dart`)
**Purpose**: Detects musical pitch from audio using the Yin algorithm  
**Algorithm**: Yin pitch detection (industry-standard for monophonic pitch detection)

**Key Features**:
- Implements complete Yin algorithm with 4 steps:
  1. Difference function
  2. Cumulative mean normalized difference
  3. Absolute threshold detection
  4. Parabolic interpolation for precision
- Instrument-specific frequency range validation
- Configurable sample rate support

**API**:
```dart
double detectPitch(List<double> audioSignal, {int sampleRate = 44100})
bool isPitchInRange(String instrument, double pitch)
```

#### 3. **NoteSegmentationService** (`note_segmentation.dart`)
**Purpose**: Segments continuous audio into individual notes  
**Algorithm**: Energy-based onset detection

**Key Features**:
- Detects note boundaries using energy analysis
- Frame-based processing (2048 samples per frame, 512 hop size)
- Adaptive thresholding
- Minimum note duration filtering (50ms)
- Converts frequencies to note names and octaves
- Confidence scoring based on signal strength

**API**:
```dart
List<Note> segmentAudio(List<double> audioData, {double sampleRate = 44100.0})
```

#### 4. **TabGeneratorService** (`tab_generator.dart`)
**Purpose**: Generates guitar tablature and text notation from notes

**Key Features**:
- Standard guitar tuning support (E A D G B E)
- Automatic string/fret position calculation
- Chord detection (simultaneous notes within 50ms)
- Text notation with timing and confidence
- Configurable fret range (0-24)
- 5% frequency tolerance for matching

**API**:
```dart
String generateTab(List<Note> notes)
String generateTextNotation(List<Note> notes)
```

#### 5. **MidiGeneratorService** (`midi_generator.dart`)
**Purpose**: Converts notes to MIDI file format  
**Standard**: MIDI 1.0 specification

**Key Features**:
- Complete MIDI file generation (header + track chunks)
- Tempo configuration (BPM)
- Instrument selection (128 MIDI instruments)
- Variable-length quantity encoding
- Velocity mapping from confidence scores
- 480 ticks per quarter note resolution

**API**:
```dart
static Future<void> generateMidiFromNotes(
  List<Note> notes,
  String outputPath,
  {int bpm = 120, int instrument = 0}
)
```

#### 6. **ExportService** (`export_service.dart`)
**Purpose**: Handles file export operations

**Key Features**:
- MIDI file export
- Guitar tab text export
- Text notation export
- Plain transcription text export
- Platform-specific path handling
- Automatic directory creation
- Timestamp-based unique filenames
- Files saved to Documents/Autotab folder

**API**:
```dart
Future<String> exportAsMidi(List<Note> notes, String fileName, {int bpm, int instrument})
Future<String> exportAsTab(List<Note> notes, String fileName)
Future<String> exportAsTextNotation(List<Note> notes, String fileName)
Future<String> exportTranscriptionText(String text, String fileName)
```

#### 7. **AudioProcessingService** (`audio_processing_service.dart`)
**Purpose**: Orchestrates the complete audio-to-transcription pipeline

**Key Features**:
- Complete processing pipeline coordination
- Instrument-based note filtering
- Real-time pitch detection support
- Comprehensive TranscriptionResult generation
- Formatted output generation

**API**:
```dart
Future<TranscriptionResult> processAudio({
  required List<double> audioData,
  double sampleRate = 44100.0,
  String instrument = 'guitar',
})
double detectRealtimePitch({required List<double> audioBuffer, int sampleRate})
```

#### 8. **AppStateProvider** (`app_state_provider.dart`)
**Purpose**: Global application state management  
**Pattern**: Provider pattern (ChangeNotifier)

**Key Features**:
- Settings management
- Transcription list management
- Current transcription tracking
- Reactive UI updates via notifyListeners()

**API**:
```dart
void updateSettings(Map<String, dynamic> newSettings)
void addTranscription(String transcription)
void removeTranscription(int index)
void setCurrentTranscription(String transcription)
```

---

### Screens (`lib/screens/`)

#### 1. **HomeScreen** (`home_screen.dart`)
**Purpose**: Main landing page

**Features**:
- Welcome screen with branding
- Navigation to Record and Export screens
- Gradient background design
- Material Design 3 styling

#### 2. **RecordScreen** (`record_screen.dart`)
**Purpose**: Audio recording with real-time visualization

**Features**:
- Recording controls (start/stop)
- Real-time audio waveform visualization
- Audio level indicator (linear progress bar)
- BPM configuration input
- Instrument selection dropdown
- Automatic transcription generation on stop
- Navigation to Edit and Export screens
- Custom AudioWaveformPainter for visualization

**State Management**:
- Subscribes to AudioService.audioLevelStream
- Updates UI at 100ms intervals
- Generates sample notes for demonstration

#### 3. **EditScreen** (`edit_screen.dart`)
**Purpose**: Transcription text editor

**Features**:
- Multi-line text editor with monospace font
- Save functionality
- Material Design card styling
- Callback-based data passing

#### 4. **ExportScreen** (`export_screen.dart`)
**Purpose**: View, manage, and export transcriptions

**Features**:
- Transcription preview/editor
- Copy to clipboard
- Three export formats:
  1. MIDI files
  2. Guitar tab text files
  3. Plain text files
- Saved transcriptions list
- Selection highlighting
- Delete functionality with smart re-selection
- Empty state UI
- Real file saving with path display

---

## Data Flow

### Recording Flow
```
User → RecordScreen → AudioService.startRecording()
  ↓
AudioService records audio → Real-time amplitude monitoring
  ↓
Audio level updates → UI waveform visualization
  ↓
User stops → AudioService.stopRecording() → Returns file path
  ↓
Generate sample notes → TabGeneratorService
  ↓
Store in AppStateProvider → Navigate to ExportScreen
```

### Export Flow
```
ExportScreen → Select transcription
  ↓
User clicks export button (MIDI/Tab/Text)
  ↓
ExportService → Generate file
  ↓
Save to Documents/Autotab/filename_timestamp.ext
  ↓
Display file path in SnackBar
```

### Audio Processing Pipeline (Design)
```
Raw Audio Samples
  ↓
NoteSegmentationService → Detect note boundaries
  ↓
PitchDetectionService → Detect pitch for each segment
  ↓
Create Note objects with timing and frequency
  ↓
TabGeneratorService → Generate tablature
  ↓
MidiGeneratorService → Generate MIDI (optional)
  ↓
ExportService → Save to file
```

---

## Key Design Decisions

### 1. **Audio Library Choice**: `record` package
- **Reason**: Better Windows support than `flutter_sound`
- **Advantage**: CMake compatibility, simpler integration
- **Trade-off**: No built-in playback (would need `just_audio` or `audioplayers`)

### 2. **Pitch Detection Algorithm**: Yin
- **Reason**: Industry standard for monophonic pitch detection
- **Advantage**: Accurate, well-tested, works across instruments
- **Trade-off**: Not suitable for polyphonic (chord) detection

### 3. **Singleton Pattern for Services**
- **Used in**: AudioService
- **Reason**: Single audio session across app lifetime
- **Advantage**: Consistent state, resource efficiency

### 4. **Provider Pattern for State**
- **Used in**: AppStateProvider
- **Reason**: Reactive UI updates, clean architecture
- **Advantage**: Separation of concerns, testability

### 5. **Platform-Specific Paths**
- **Implementation**: Conditional logic based on Platform.isWindows/Linux/macOS
- **Reason**: Each OS has different conventions
- **Location**: Documents/Autotab folder for user accessibility

---

## Testing

Test files are implemented in `test/` directory:
- `pitch_detection_test.dart` - Tests Yin algorithm accuracy
- `note_segmentation_test.dart` - Tests note boundary detection
- `tab_generator_test.dart` - Tests tablature generation
- `midi_generator_test.dart` - Tests MIDI file format

Run tests with:
```bash
flutter test
```

---

## Building for Windows

### Requirements
- Flutter SDK (with Windows support enabled)
- Visual Studio 2019 or later with C++ desktop development workload
- CMake 3.14 or later

### Build Commands
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for Windows
flutter build windows

# Or run directly
flutter run -d windows
```

### Output Location
- Debug: `build/windows/x64/runner/Debug/`
- Release: `build/windows/x64/runner/Release/`

---

## Future Enhancements

### Phase 1: Audio File Support
- Add audio file picker
- Implement audio decoding (WAV, MP3, etc.)
- Process existing audio files

### Phase 2: Real Audio Processing
- Integrate actual audio processing in RecordScreen
- Replace sample notes with real pitch detection
- Process recorded audio buffer

### Phase 3: Playback
- Add `just_audio` or `audioplayers` package
- Implement playback controls
- Sync playback with visualization

### Phase 4: Advanced Features
- PDF export with notation rendering
- Polyphonic detection (chords)
- Multiple instrument support (bass, piano, etc.)
- Cloud storage integration
- Sharing functionality

### Phase 5: Mobile Support
- Android/iOS platform integration
- Mobile-specific UI adaptations
- Platform-specific audio handling

---

## Dependencies

### Production
```yaml
flutter: sdk
record: ^5.0.0           # Audio recording
provider: ^6.0.0         # State management
permission_handler: ^12.0.0  # Microphone permissions
```

### Development
```yaml
flutter_test: sdk
build_runner: ^2.0.0
json_serializable: ^6.0.0
flutter_lints: ^1.0.0
```

---

## File Structure Summary

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── note.dart                      # Note data model
│   ├── settings.dart                  # Settings model
│   └── transcription.dart             # Transcription model
├── services/
│   ├── audio_service.dart             # Recording & amplitude
│   ├── pitch_detection.dart           # Yin algorithm
│   ├── note_segmentation.dart         # Onset detection
│   ├── tab_generator.dart             # Tablature generation
│   ├── midi_generator.dart            # MIDI file creation
│   ├── export_service.dart            # File export operations
│   ├── audio_processing_service.dart  # Pipeline orchestration
│   └── app_state_provider.dart        # State management
└── screens/
    ├── home_screen.dart               # Landing page
    ├── record_screen.dart             # Recording interface
    ├── edit_screen.dart               # Text editor
    └── export_screen.dart             # Export management
```

---

## License
This project is part of the Autotab music transcription application.

## Support
For issues and questions, refer to the project repository or documentation.
