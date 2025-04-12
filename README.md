# ScanVault

A powerful document scanning application for iOS that allows users to scan, organize, and store documents securely in iCloud.

## Overview

ScanVault is an iPhone application designed to facilitate quick document scanning using Apple's native document scanner. Users can organize their scanned documents using a flexible tagging and folder system, managed within the app's Vault. Documents are stored in a flat database structure, with folder assignments acting as metadata rather than physical file system locations.

The application opens directly to the Scan Screen to streamline the scanning process.

## Features

### Document Scanning & Storage
- Utilize Apple's native document scanner (VisionKit) to scan new documents
- After scanning, assign a title, tags (0 or many), and an optional folder
- Documents stored in a flat database structure with folder assignments as metadata
- Add comments to any scanned document
- Save documents with or without tags and folders

### The Vault (Document Management System)
- Search and filter documents by:
  - Title
  - Date range (From/To)
  - Tags (one or many)
  - Folders
- Default date search behavior automatically uses earliest scan date to today
- Document viewer allows:
  - Updating title, tags, and folder assignment
  - Adding new folders or tags
  - Adding comments
  - Removing tags
  - Using Apple's Share feature

### User Authentication
- Login required to use the application
- Standard username/password management:
  - Change password within the app
  - Forgot username
  - Forgot password

### Subscription Management
- Two subscription levels:
  - Basic (Free)
    - Full app functionality
    - Documents accessible only while using the app
  - Premium ($4.99/month)
    - Bulk export of documents
    - Cross-device access
    - iCloud sync for long-term storage
- Subscription Management
  - Upgrade from Basic to Premium
  - Downgrade from Premium to Basic

## Technical Details

### Architecture
- MVVM architecture pattern
- Core Data for local data persistence
- CloudKit for Premium users' document syncing
- SwiftUI for the user interface

### Key Components
- Models: Core Data models for Document, Tag, and Folder entities
- Views: SwiftUI views for user interface
- ViewModels: Business logic and data management
- Services: Authentication, scanning, and storage services

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Active Apple Developer Account

## Setup

1. Clone the repository
2. Open ScanVault.xcodeproj in Xcode
3. Configure your development team in project settings
4. Enable iCloud capabilities in your project settings
5. Build and run the project

## Future Enhancements

- MacOS App Support
- AI-powered Smart Tagging
- OCR Text Recognition & Search
- Document Collaboration/Sharing Features
- Integration with Third-Party Cloud Services

## License

Copyright © 2024 ScanVault. All rights reserved.

# End of Rules