Project: Obsidian Vault Sync Lite
One-line description

A lightweight Android app that synchronizes a local Obsidian vault folder with a Google Drive folder using manual Sync Up and Sync Down operations.

Problem Statement

Obsidian mobile cannot directly use Google Drive as a live filesystem, and Linux users lack a seamless Google Drive sync experience.

Existing solutions are often:

Over-featured
Dependent on subscriptions
Hard to configure
Designed for generic file sync instead of Markdown-first note vaults

This project solves a narrow problem:

Sync an Obsidian vault between Android and Google Drive with explicit user-controlled direction.

Scope (strict MVP)

Only two actions:

Sync Up
Phone Local Vault ───► Google Drive

Uploads changed files from the device to Drive.

Sync Down
Google Drive ───► Phone Local Vault

Downloads changed files from Drive.

No automatic syncing.

No background service.

No conflict resolution.

No account switching.

No multi-vault support.

Keep it tiny.

Functional Requirements
FR1 — Google Authentication

User signs into Google account.

Output:

Authenticated Drive access
FR2 — Folder Selection

User selects:

Local vault folder

Example:

/Documents/Obsidian_Vault

and

Drive vault folder

Example:

/Obsidan

Store preferences locally.

FR3 — Sync Up Button

When user taps:

Sync Up

App:

Scans local vault
Compares modified timestamps
Uploads newer local files
Skips unchanged files

Rule:

Local newer → upload
FR4 — Sync Down Button

When user taps:

Sync Down

App:

Reads Drive metadata
Compares timestamps
Downloads newer cloud files

Rule:

Cloud newer → download
FR5 — Status Screen

Show:

Files scanned
Files uploaded
Files downloaded
Skipped files
Last sync time
Non-functional Requirements
Lightweight

Goal:

< 20 MB APK
Fast

Avoid re-uploading unchanged files.

Use metadata comparison.

Safe

Never delete files.

MVP rule:

No deletions
No overwrite without comparison
System Architecture
+----------------------+
| Android UI           |
| Sync Up / Down       |
+----------+-----------+
           |
           v
+----------------------+
| Sync Engine          |
| compare timestamps   |
| upload/download      |
+----------+-----------+
           |
           v
+----------------------+
| Google Drive API     |
+----------------------+
           ^
           |
+----------------------+
| Local Vault Storage  |
+----------------------+
Tech Stack
Language: Kotlin/Go
UI: Jetpack Compose
Background task (optional later): WorkManager
Local storage: Room / SharedPreferences
Cloud API: Google Drive REST API
File monitoring (future): FileObserver
Folder Structure
app/
 ├── ui/
 ├── sync/
 │    ├── SyncEngine.kt
 │    ├── UploadManager.kt
 │    ├── DownloadManager.kt
 │    └── MetadataComparator.kt
 ├── drive/
 │    └── GoogleDriveClient.kt
 ├── storage/
 │    └── VaultScanner.kt
 └── models/
Sync Logic (MVP)

Pseudo algorithm:

for each file in local vault:
    if not exists in drive:
        upload
    else if local modified_time > drive modified_time:
        upload
    else:
        skip

Sync down:

for each file in drive:
    if not exists locally:
        download
    else if drive modified_time > local modified_time:
        download
    else:
        skip