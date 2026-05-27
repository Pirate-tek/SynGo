# SyncGo

SyncGo is a lightweight, clean, and focused synchronization utility for Android built with Flutter. It bridges the gap for Obsidian users who want to keep their Markdown-based note vaults synchronized with Google Drive without relying on background services, complex configurations, or recurring subscriptions.

SyncGo follows a strict "manual-first" paradigm, giving you complete, explicit control over when and in which direction your vault synchronizes.


## The Problem

On mobile devices, Obsidian cannot directly interface with Google Drive as a live filesystem. Existing solutions are often over-engineered, require subscriptions, rely on complex configurations, or are designed for general file-syncing rather than markdown vaults. 

SyncGo solves a narrow problem: allowing you to sync a local vault folder with Google Drive using precise, user-directed sync actions.


## Core Paradigm

To keep the application highly reliable and safe, SyncGo operates on three core principles:

- **Explicit Direction**: Synchronization is triggered manually via two primary actions:
  - **Sync Up**: Local device files are scanned and uploaded to Google Drive if they are newer or do not exist in the cloud.
  - **Sync Down**: Google Drive is scanned and files are downloaded to the local device if they are newer or do not exist locally.
- **Safety First**: SyncGo will never delete your files. If a file is deleted on one end, it is not deleted on the other during a sync. The MVP sync algorithm is additive and updating-only.
- **Zero Background Overhead**: There are no background services, silent sync runners, or battery-draining monitors. SyncGo only runs when you open the app and tap sync.


## Architecture & Tech Stack

SyncGo is built with a modern, reactive stack on Flutter:

- **Framework**: Flutter (Dart) for high-performance cross-platform execution.
- **State Management**: Flutter Riverpod for robust, decoupled dependency injection and reactive state synchronization.
- **Google Authentication**: Integration via `google_sign_in` and `googleapis_auth` for secure, native Google Drive access.
- **Storage & Metadata**: Local preference storage with SharedPreferences and file picking via File Picker.
- **UI & Experience**: Material 3 theme incorporating Google Fonts and fluid micro-animations powered by Flutter Animate.


## Directory Structure

```
lib/
├── drive/          # Google Drive API client and authentication flow
├── models/         # Sync status and configuration models
├── presentation/   # Jetpack-inspired Material 3 screens and widgets
├── providers/      # Riverpod providers managing reactive sync state
├── storage/        # Vault file scanners and local metadata processors
└── sync/           # Sync engine comparing local and remote timestamps
```


## Getting Started

### Prerequisites

To build and run SyncGo, ensure you have the following installed:
- Flutter SDK (version 3.12.0 or higher)
- Android SDK (for deployment on Android devices)

### Setup & Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/syncgo.git
   cd syncgo
   ```

2. Retrieve dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Google Sign-In:
   To authenticate with Google Drive, you will need to register your app in the Google Cloud Console, enable the Google Drive API, and provide your client configuration.
   - For Android, ensure you update your SHA-1 fingerprints in the Google Cloud Console.

4. Run the application:
   ```bash
   flutter run
   ```


## License

This project is licensed under the MIT License - see the LICENSE file for details.
