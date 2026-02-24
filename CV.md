# Ivan Kiselev — Curriculum Vitae

📧 <!-- add your email -->  
🌍 <!-- add your location -->  
💼 [LinkedIn](https://www.linkedin.com/in/ivan-kiselev-75b802b8/)  
🐙 [GitHub](https://github.com/ivankiselev89)

---

## Profile

Passionate mobile software developer with hands-on experience building cross-platform applications using Flutter and Dart. Proven ability to design and deliver complete product cycles — from architecture and UI/UX implementation to testing and deployment. Enthusiastic about combining software engineering with creative domains such as music technology.

---

## Skills

### Languages & Frameworks
- **Dart / Flutter** — cross-platform mobile, web, and desktop development
- State management: **Provider**, MVVM-style architecture
- Audio processing, pitch detection (Yin algorithm), MIDI file generation
- Unit and widget testing with `flutter_test`

### Tools & Practices
- Git / GitHub
- Test-Driven Development (TDD)
- CI/CD (GitHub Actions, CodeQL security scanning)
- Agile / iterative development
- Android & iOS deployment (permissions, manifests, entitlements)
- Multi-platform Flutter builds: Android, iOS, Web, Windows, macOS, Linux

### Other
- Music theory and guitar tab notation
- Digital signal processing concepts (onset detection, FFT-based pitch analysis)

---

## Projects

### Autotab — Mobile Music Transcription App *(2026 – present)*
> [github.com/ivankiselev89/Autotab](https://github.com/ivankiselev89/Autotab)

A fully cross-platform Flutter application that records audio and automatically transcribes it to guitar tablature and MIDI files.

**Key contributions:**
- Designed the complete app architecture (screens, services, data models) following MVVM principles
- Implemented `PitchDetectionService` using the Yin algorithm with parabolic interpolation for accurate note detection
- Built `NoteSegmentationService` with energy-based onset detection and frequency-to-note mapping
- Developed `TabGeneratorService` for optimal 6-string guitar fret positioning and chord detection
- Created `MidiGeneratorService` producing standards-compliant SMF Format 0 MIDI files
- Wrote 39+ unit tests covering all core music-processing services
- Authored end-user and developer documentation (guides, API docs)
- Passed CodeQL security scanning with zero vulnerabilities

**Tech stack:** Dart, Flutter, Provider, `record`, `audioplayers`, `path_provider`, `permission_handler`

---

## Education

<!-- Add your educational background here, e.g.:
**[Degree]**, [University / Institution], [Year]
-->

---

## Work Experience

<!-- Add your professional experience here, e.g.:
### [Job Title] — [Company Name] *(Month Year – Month Year)*
- Key responsibility / achievement
- Key responsibility / achievement
-->

---

## Languages

<!-- e.g.: Russian (native), English (professional working proficiency) -->

---

## Interests

Music, guitar, software craftsmanship, audio technology, open-source development.

---

*Last updated: February 2026*
