# Getting Started

Welcome to the Autotab project! Follow these instructions to set up the development environment for Flutter, Android, iOS, and the local development workflow.

## Flutter Development Setup
1. **Install Flutter**:
   - Download Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install).
   - Extract the downloaded archive and add the `flutter/bin` directory to your system's PATH.

2. **Verify the Installation**:
   - Run `flutter doctor` in the terminal to check for any dependencies you might need to install.

## Android Development Setup
1. **Install Android Studio**:
   - Download Android Studio from [developer.android.com/studio](https://developer.android.com/studio).
   - Follow the installation guide to set up Android Studio and Android SDK.

2. **Configure Android SDK**:
   - Open Android Studio, go to `File > Settings > Appearance & Behavior > System Settings > Android SDK` and ensure the latest SDK tools are installed.

3. **Set up an Emulator**:
   - Use Android Studio AVD Manager to create a virtual device for testing.

## iOS Development Setup
1. **Install Xcode**:
   - Install Xcode from the Mac App Store.

2. **Set up Xcode Command Line Tools**:
   - Open Xcode and go to `Preferences > Locations`, and ensure the Command Line Tools are set to your version of Xcode.

## Local Development Workflow
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/ivankiselev89/Autotab.git
   cd Autotab
   ```

2. **Install Dependencies**:
   - Ensure you have the Flutter dependencies installed:
   ```bash
   flutter pub get
   ```

3. **Run the Application**:
   - You can run your application on an emulator or a connected device:
   ```bash
   flutter run
   ```

4. **Hot-Reload**:
   - Make changes to your code and use `r` in the terminal to hot-reload the app running on your device/emulator for quick feedback.

## Conclusion
Congratulations! You are now set up for development. Happy coding!