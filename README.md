# ScanVault

A powerful document scanning application for iOS that allows users to scan, organize, and store documents securely in iCloud with advanced AI capabilities for document classification and research.

## Overview

ScanVault is an iPhone application designed to facilitate quick document scanning using Apple's native document scanner. Users can organize their scanned documents using a flexible tagging and folder system, managed within the app's Vault. Documents are stored in a flat database structure, with folder assignments acting as metadata rather than physical file system locations.

The application opens directly to the Scan Screen to streamline the scanning process and includes AI-powered document classification to automate organization tasks.

## Features

### Document Scanning & Storage
- Utilize Apple's native document scanner (VisionKit) to scan new documents
- After scanning, assign a title, tags (0 or many), and an optional folder
- Documents stored in a flat database structure with folder assignments as metadata
- Add comments to any scanned document
- Save documents with or without tags and folders
- OCR text extraction from scanned documents
- AI-powered document classification that suggests appropriate titles, folders, and tags

### The Vault (Document Management System)
- Search and filter documents by:
  - Title
  - Date range (From/To)
  - Tags (one or many)
  - Folders
  - OCR text content
- Default date search behavior automatically uses earliest scan date to today
- Document viewer allows:
  - Updating title, tags, and folder assignment
  - Adding new folders or tags
  - Adding comments
  - Removing tags
  - Using Apple's Share feature

### AI Document Research
- AI-powered document analysis and research
- Ask questions about document content using natural language
- Cross-document research across multiple files
- Document summarization and key point extraction
- Multiple AI model support (GPT-3.5, GPT-4, GPT-4o)
- Customizable AI settings for different research needs
- Token usage monitoring and cost estimation

### AI Document Classification
- Automatic classification of documents during import
- Intelligent title, folder, and tag suggestions
- Adaptive learning from user preferences and tagging patterns
- Confidence scores for classification suggestions
- Premium-only feature with model selection options

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
    - AI document classification
    - Advanced AI research capabilities
- Subscription Management
  - Upgrade from Basic to Premium
  - Downgrade from Premium to Basic

## Technical Details

### Architecture
- MVVM architecture pattern
- Core Data for local data persistence
- CloudKit for Premium users' document syncing
- SwiftUI for the user interface
- OpenAI integration for document classification and research

### Key Components
- Models: Core Data models for Document, Tag, and Folder entities
- Views: SwiftUI views for user interface
- ViewModels: Business logic and data management
- Services: 
  - Authentication and security services
  - Document scanning and OCR processing
  - AI integration (OpenAI)
  - Document classification
  - Adaptive learning classification
  - Secure API key management

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Active Apple Developer Account
- OpenAI API key (for AI features)

## Setup

1. Clone the repository
2. Open ScanVault.xcodeproj in Xcode
3. Configure your development team in project settings
4. Enable iCloud capabilities in your project settings
5. For AI features, add your OpenAI API key in the Settings screen
6. Build and run the project

## Future Enhancements

- MacOS App Support
- Enhanced AI-powered document processing
- Expanded document collaboration features
- Integration with Third-Party Cloud Services
- Custom fine-tuned AI models for specific document types

## License

Copyright © 2024 ScanVault. All rights reserved.

# End of Rules