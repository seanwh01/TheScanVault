import Foundation
import CloudKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages synchronization of app data across devices using CloudKit
class CloudSyncManager {
    // MARK: - Shared Instance
    
    /// Shared instance of the CloudSync manager
    static let shared = CloudSyncManager()
    
    // MARK: - Properties
    
    /// The container identifier for the CloudKit container
    private let containerIdentifier = "iCloud.com.TSV.app"
    
    /// The record type for document locks
    private let lockRecordType = "DocumentLock"
    
    /// The CloudKit container
    private lazy var container: CKContainer = {
        return CKContainer(identifier: containerIdentifier)
    }()
    
    /// The private database in CloudKit
    private lazy var privateDatabase: CKDatabase = {
        return container.privateCloudDatabase
    }()
    
    /// Custom zone ID for document locks
    private lazy var customZoneID: CKRecordZone.ID = {
        return CKRecordZone.ID(zoneName: "DocumentLockZone", ownerName: CKCurrentUserDefaultName)
    }()
    
    /// The current app device ID
    private lazy var deviceId: String = {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        let hostName = Host.current().localizedName ?? "mac"
        return "\(hostName)_\(UUID().uuidString)"
        #endif
    }()
    
    /// Timestamp of the last sync
    private var lastSyncTime: Date?
    
    // Flag to indicate if we're connected to iCloud
    private var isCloudAvailable: Bool = false
    
    // Flag to disable simulator detection for testing real CloudKit in simulator
    public var forceRealCloudKit: Bool = false
    
    // Flag to indicate if we're running in simulator
    private var isRunningInSimulator: Bool {
        if forceRealCloudKit { return false }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // Flag to control logging verbosity
    private var isVerboseLogging: Bool = false
    
    // Store currently locked documents as UUIDs
    private var lockedDocuments = Set<UUID>()
    
    // Document title cache to improve logging readability
    private var documentTitleCache: [String: String] = [:]
    
    private var lastLoggedTime: [UUID: Date] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Check iCloud status on initialization
        checkCloudAvailability()
        
        // Set up notification observers for app state changes
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Set up notification for app becoming active to sync locks
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
        
        // Listen for CloudKit account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitAccountChanged),
            name: .CKAccountChanged,
            object: nil
        )
        
        // Listen for lock changes to trigger sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentLockChanged),
            name: NSNotification.Name("DocumentLocked"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentLockChanged),
            name: NSNotification.Name("DocumentUnlocked"),
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        print("📱 App became active, checking iCloud and syncing locks")
        checkCloudAvailability()
        fetchLockedDocuments { documents, error in
            if let error = error {
                print("❌ Error syncing on app activation: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleCloudKitAccountChanged() {
        print("☁️ iCloud account changed, rechecking availability")
        checkCloudAvailability()
    }
    
    @objc private func handleDocumentLockChanged(notification: Notification) {
        print("🔄 Document lock changed, scheduling sync")
        // Get the document ID from notification
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            print("📄 Lock changed for document: \(documentId)")
        }
        
        // Schedule sync with a small delay to allow batching of changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Get all locked documents from DocumentLockService
            if let documents = self.getAllLockedDocumentsFromService() {
                self.syncLockedDocuments(documents) { error in
                    if let error = error {
                        print("❌ Error syncing after lock change: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func log(_ message: String, level: LogLevel = .info) {
        guard level == .error || isVerboseLogging else { return }
        
        let prefix: String
        switch level {
        case .error:
            prefix = "❌"
        case .warning:
            prefix = "⚠️"
        case .info:
            prefix = "ℹ️"
        case .debug:
            prefix = "🔍"
        }
        
        print("\(prefix) \(message)")
    }
    
    private enum LogLevel {
        case error
        case warning
        case info
        case debug
    }
    
    private func getDocumentDisplayName(for documentId: String) -> String {
        if let cachedTitle = documentTitleCache[documentId] {
            return cachedTitle
        }
        return "Document"
    }
    
    // Add an overload that accepts UUID and converts to string
    private func getDocumentDisplayName(for documentId: UUID) -> String {
        return getDocumentDisplayName(for: documentId.uuidString)
    }
    
    /// Update the document title cache for better log readability
    func updateDocumentTitleCache(_ titles: [String: String]) {
        documentTitleCache.merge(titles) { (_, new) in new }
    }
    
    // Make this public for testing purposes
    public func checkCloudAvailability(retryCount: Int = 3) {
        // Check if we're in simulator - provide better debug info
        if isRunningInSimulator {
            log("Running in simulator environment - iCloud status might be limited", level: .debug)
        }
        
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [self] in
                let wasAvailable = self.isCloudAvailable
                
                switch status {
                case .available:
                    self.log("iCloud is available", level: .info)
                    self.isCloudAvailable = true
                    
                    // Notify if availability changed
                    if !wasAvailable {
                        self.notifyCloudAvailabilityChanged(available: true)
                    }
                    
                    // Setup subscription once we confirm iCloud is available
                    self.setupSubscriptionIfNeeded()
                    
                case .noAccount, .restricted, .couldNotDetermine, _:
                    // Handle all unavailable states
                    let statusString: String
                    switch status {
                    case .noAccount: statusString = "No iCloud account"
                    case .restricted: statusString = "iCloud access restricted"
                    case .couldNotDetermine: statusString = "Could not determine iCloud status"
                    default: statusString = "Unknown iCloud account status"
                    }
                    self.log("\(statusString)", level: .warning)
                    
                    // Notify if availability changed
                    if wasAvailable {
                        self.isCloudAvailable = false
                        self.notifyCloudAvailabilityChanged(available: false)
                    }
                    
                    // If we still have retries left, try again after delay
                    if retryCount > 0 {
                        self.log("Retrying iCloud availability check in 2 seconds... (\(retryCount) retries left)", level: .info)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                            self?.checkCloudAvailability(retryCount: retryCount - 1)
                        }
                    } else {
                        self.log("iCloud availability check failed after multiple attempts", level: .error)
                        self.isCloudAvailable = false
                    }
                }
            }
        }
    }
    
    // Helper method to notify about cloud availability changes
    private func notifyCloudAvailabilityChanged(available: Bool) {
        print("☁️ iCloud availability changed: \(available ? "available" : "unavailable")")
        
        // If iCloud just became available, immediately try to sync document locks
        if available {
            print("☁️ iCloud just became available, forcing document lock sync")
            fetchLockedDocuments { documentIds, error in
                if let error = error {
                    print("⚠️ Error syncing document locks after iCloud became available: \(error.localizedDescription)")
                    
                    // Schedule a retry after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.fetchLockedDocuments { _, _ in }
                    }
                } else if let documentIds = documentIds {
                    print("✅ Successfully synced \(documentIds.count) document locks after iCloud became available")
                }
            }
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CloudKitAvailabilityChanged"),
            object: nil,
            userInfo: ["available": available]
        )
    }
    
    // MARK: - Public Methods
    
    /// Check if iCloud is available
    public func checkIsCloudAvailable() -> Bool {
        return isCloudAvailable
    }
    
    /// Sync locked documents to CloudKit
    func syncLockedDocuments(_ documentIds: [String], completion: @escaping (Error?) -> Void) {
        // Skip if cloud is not available
        guard isCloudAvailable else {
            log("iCloud not available, skipping sync", level: .warning)
            completion(NSError(domain: "CloudSyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"]))
            return
        }
        
        let documentDisplayNames = documentIds.map { getDocumentDisplayName(for: $0) }.joined(separator: ", ")
        log("Syncing documents: \(documentDisplayNames)", level: .info)
        
        // Create record ID with a SHARED recordName (not device-specific)
        let recordID = CKRecord.ID(recordName: "all_device_locks")
        
        // First try to fetch the existing record
        privateDatabase.fetch(withRecordID: recordID) { [weak self] (existingRecord, error) in
            guard let self = self else { return }
            
            var record: CKRecord
            
            if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Record doesn't exist yet, create a new one
                record = CKRecord(recordType: self.lockRecordType, recordID: recordID)
                self.log("Creating new record for document locks", level: .info)
            } else if let error = error {
                // Some other error occurred during fetch
                self.log("Error fetching lock record: \(error.localizedDescription)", level: .error)
                completion(error)
                return
            } else if let existingRecord = existingRecord {
                // Use the existing record
                record = existingRecord
                self.log("Updating existing lock record", level: .info)
            } else {
                // This shouldn't happen, but just in case
                record = CKRecord(recordType: self.lockRecordType, recordID: recordID)
                self.log("Creating new record (fallback case)", level: .warning)
            }
            
            // Set your fields - don't rely on lockIdentifier if it's not in schema
            record["lockedDocuments"] = documentIds as CKRecordValue
            record["deviceId"] = self.deviceId as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            
            // Try to add lockIdentifier but handle errors if field doesn't exist
            self.log("Saving to CloudKit: \(documentDisplayNames)", level: .debug)
            self.privateDatabase.save(record) { (savedRecord, error) in
                if let error = error as? CKError {
                    if error.localizedDescription.contains("Unknown field 'lockIdentifier'") {
                        // Field doesn't exist in schema, the record was still saved without that field
                        self.log("lockIdentifier field not recognized but record saved", level: .warning)
                        
                        // Update last sync time
                        self.lastSyncTime = Date()
                        self.log("Successfully synced documents to CloudKit: \(documentDisplayNames)", level: .info)
                        
                        // Post notification about successful sync
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CloudSyncCompleted"),
                            object: nil,
                            userInfo: ["documentCount": documentIds.count]
                        )
                        
                        completion(nil)
                    } else if error.code == .serverRecordChanged || error.localizedDescription.contains("record to insert already exists") {
                        // The record already exists or was changed, we need to fetch it and update
                        self.log("Record conflict detected, retrying with forced update", level: .warning)
                        self.retryForcedRecordUpdate(documentIds: documentIds, completion: completion)
                    } else {
                        self.log("Error syncing locked documents to CloudKit: \(error.localizedDescription)", level: .error)
                        completion(error)
                    }
                } else if let error = error {
                    self.log("Error syncing locked documents to CloudKit: \(error.localizedDescription)", level: .error)
                    completion(error)
                } else {
                    // Update last sync time
                    self.lastSyncTime = Date()
                    self.log("Successfully synced documents to CloudKit: \(documentDisplayNames)", level: .info)
                    
                    // Post notification about successful sync
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CloudSyncCompleted"),
                        object: nil,
                        userInfo: ["documentCount": documentIds.count]
                    )
                    
                    completion(nil)
                }
            }
        }
    }
    
    /// Retry saving a record with a more aggressive update approach
    private func retryForcedRecordUpdate(documentIds: [String], completion: @escaping (Error?) -> Void) {
        let documentDisplayNames = documentIds.map { getDocumentDisplayName(for: $0) }.joined(separator: ", ")
        
        // Try the alternative query to find the record
        let query = CKQuery(recordType: lockRecordType, predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.log("Error during forced record update: \(error.localizedDescription)", level: .error)
                completion(error)
                return
            }
            
            guard let records = records, !records.isEmpty else {
                self.log("No records found during forced update - creating new record", level: .warning)
                
                // Create a new record with a different ID to avoid conflicts
                let recordID = CKRecord.ID(recordName: "all_device_locks_\(Date().timeIntervalSince1970)")
                let record = CKRecord(recordType: self.lockRecordType, recordID: recordID)
                
                record["lockedDocuments"] = documentIds as CKRecordValue
                record["deviceId"] = self.deviceId as CKRecordValue
                record["updatedAt"] = Date() as CKRecordValue
                
                self.privateDatabase.save(record) { (_, error) in
                    if let error = error {
                        self.log("Error creating alternate record: \(error.localizedDescription)", level: .error)
                        completion(error)
                    } else {
                        self.log("Successfully created alternate record for locks", level: .info)
                        self.lastSyncTime = Date()
                        completion(nil)
                    }
                }
                return
            }
            
            // Find the main record or use the first one
            let recordToUpdate = records.first(where: { $0.recordID.recordName == "all_device_locks" }) ?? records.first!
            
            // Update the record
            recordToUpdate["lockedDocuments"] = documentIds as CKRecordValue
            recordToUpdate["deviceId"] = self.deviceId as CKRecordValue
            recordToUpdate["updatedAt"] = Date() as CKRecordValue
            
            self.log("Updating existing record with forced approach", level: .info)
            
            self.privateDatabase.save(recordToUpdate) { (_, error) in
                if let error = error {
                    self.log("Error updating record with forced approach: \(error.localizedDescription)", level: .error)
                    completion(error)
                } else {
                    self.log("Successfully updated locks with forced approach: \(documentDisplayNames)", level: .info)
                    self.lastSyncTime = Date()
                    
                    // Post notification about successful sync
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CloudSyncCompleted"),
                        object: nil,
                        userInfo: ["documentCount": documentIds.count]
                    )
                    
                    completion(nil)
                }
            }
        }
    }
    
    /// Fetch locked documents from CloudKit
    func fetchLockedDocuments(completion: @escaping ([String]?, Error?) -> Void) {
        print("🔍 CLOUD FETCH: Starting fetchLockedDocuments in CloudSyncManager")
        print("🔍 CLOUD FETCH: Using container: \(container.containerIdentifier ?? "unknown")")

        // Safety check for iCloud availability
        if !isCloudAvailable {
            print("❌ iCloud not available - cannot fetch locked documents")
            
            // Load from local storage as fallback
            loadLockedDocumentsFromLocalStorage()
            
            completion(nil, NSError(domain: "CloudKitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"]))
            return
        }
        
        print("🔍 CLOUD FETCH: Fetching locked documents record with ID 'all_device_locks'")
        
        // Fetch locked documents from CloudKit using direct record fetch
        let recordID = CKRecord.ID(recordName: "all_device_locks")
        privateDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ CLOUD FETCH ERROR: \(error.localizedDescription)")
                
                if let ckError = error as? CKError {
                    print("🔍 CLOUD FETCH: CKError code: \(ckError.code.rawValue)")
                    if ckError.code == .unknownItem {
                        print("🔍 CLOUD FETCH: Record 'all_device_locks' doesn't exist yet")
                    } else if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                        print("🔍 CLOUD FETCH: Network issue with CloudKit")
                    } else if ckError.code == .serverRejectedRequest {
                        print("🔍 CLOUD FETCH: Server rejected request - possible permission issue")
                    } else if ckError.code == .zoneBusy {
                        print("🔍 CLOUD FETCH: Zone is busy, retry later")
                    }
                }
                
                // Try with alternative query
                print("🔍 CLOUD FETCH: Falling back to alternative query method")
                self.fetchLockedDocumentsWithAlternativeQuery { (docIds, queryError) in
                    // After both attempts failed, try to use local storage
                    if queryError != nil {
                        self.loadLockedDocumentsFromLocalStorage()
                    }
                    
                    completion(docIds, queryError)
                }
                return
            }
            
            guard let record = record else {
                print("⚠️ CLOUD FETCH: Record was successfully fetched but is nil - this is unusual")
                self.fetchLockedDocumentsWithAlternativeQuery(completion: completion)
                return
            }
            
            print("✅ CLOUD FETCH: Successfully retrieved 'all_device_locks' record")
            
            // Examine the record's metadata for debugging
            print("🔍 CLOUD FETCH METADATA: Record Type: \(record.recordType)")
            print("🔍 CLOUD FETCH METADATA: Record Modified Date: \(record.modificationDate?.description ?? "unknown")")
            print("🔍 CLOUD FETCH METADATA: Available Keys: \(record.allKeys().joined(separator: ", "))")
            
            if let lockedDocsArray = record["lockedDocuments"] as? [String] {
                // Log all document IDs for debugging cross-platform issues
                print("🔍 Found \(lockedDocsArray.count) locked document IDs from CloudKit:")
                for docId in lockedDocsArray {
                    let docName = self.getDocumentDisplayName(for: docId)
                    print("   - '\(docName)' (\(docId))")
                }
                
                // Process changes on a background thread to avoid UI conflicts
                DispatchQueue.global(qos: .userInitiated).async {
                    // Update with the documents from CloudKit
                    let oldDocs = self.lockedDocuments
                    let newDocs = Set(lockedDocsArray.compactMap { UUID(uuidString: $0) })
                    
                    // Log details about the conversion process
                    print("🔍 CLOUD FETCH: Converted \(newDocs.count) of \(lockedDocsArray.count) strings to valid UUIDs")
                    
                    if newDocs.count != lockedDocsArray.count {
                        print("⚠️ CLOUD FETCH: Some document IDs could not be converted to valid UUIDs:")
                        for docId in lockedDocsArray {
                            if UUID(uuidString: docId) == nil {
                                print("   ❌ Invalid UUID format: \(docId)")
                            }
                        }
                    }
                    
                    // Save the documents to local storage for offline access
                    UserDefaults.standard.set(lockedDocsArray, forKey: "com.scanvault.lockedDocuments")
                    print("💾 Saved \(lockedDocsArray.count) locked documents to local storage")
                    
                    // Update the local set with UUIDs from CloudKit
                    self.lockedDocuments = newDocs
                    
                    // Determine if there's a meaningful change to reduce unnecessary UI updates
                    let hasChanged = oldDocs != newDocs
                    
                    // Log what documents have been added or removed
                    let addedDocs = newDocs.subtracting(oldDocs)
                    let removedDocs = oldDocs.subtracting(newDocs)
                    
                    print("🔍 CLOUD FETCH CHANGES: \(addedDocs.count) docs being added, \(removedDocs.count) docs being removed")
                    
                    if !addedDocs.isEmpty {
                        print("🔍 CLOUD FETCH ADDED: Documents being added to locked state:")
                        for docId in addedDocs {
                            let docName = self.getDocumentDisplayName(for: docId.uuidString)
                            print("   + '\(docName)' (\(docId))")
                        }
                    }
                    
                    if !removedDocs.isEmpty {
                        print("🔍 CLOUD FETCH REMOVED: Documents being removed from locked state:")
                        for docId in removedDocs {
                            let docName = self.getDocumentDisplayName(for: docId.uuidString)
                            print("   - '\(docName)' (\(docId))")
                        }
                    }
                    
                    print("✅ Updated lock state with \(lockedDocsArray.count) documents from CloudKit (was \(oldDocs.count))")
                    print("🔒 Currently locked documents:")
                    for docId in self.lockedDocuments {
                        let docName = self.getDocumentDisplayName(for: docId.uuidString)
                        print("  - '\(docName)' (\(docId))")
                    }
                    
                    // Back to main thread for UI notifications
                    DispatchQueue.main.async {
                        // Batch these notifications together to minimize UI thrashing
                        if hasChanged {
                            // Document lock changes notification
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DocumentLocksChanged"),
                                object: nil
                            )
                        }
                        
                        // Check password sync (low frequency)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CheckPasswordSync"),
                            object: nil
                        )
                        
                        // Sync completion notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CloudSyncCompleted"),
                            object: nil,
                            userInfo: ["documentCount": lockedDocsArray.count]
                        )
                    }
                    
                    // Complete the operation
                    completion(lockedDocsArray, nil)
                }
            } else {
                print("⚠️ CLOUD FETCH: Lock record found but 'lockedDocuments' field is missing or not an array")
                print("🔍 CLOUD FETCH: Available keys in record: \(record.allKeys().joined(separator: ", "))")
                print("🔍 CLOUD FETCH: Record: \(record)")
                completion([], nil)
            }
        }
    }
    
    /// Alternative method to fetch locked documents if the primary method fails
    private func fetchLockedDocumentsWithAlternativeQuery(completion: @escaping ([String]?, Error?) -> Void) {
        print("🔍 ALT QUERY: Starting alternative query for document locks")
        
        // Create a query for all DocumentLock records - we know there should only be a few
        let query = CKQuery(recordType: lockRecordType, predicate: NSPredicate(value: true))
        
        // Sort by updatedAt if available
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        print("🔍 ALT QUERY: Executing CKQuery for record type: \(lockRecordType)")
        print("🔍 ALT QUERY: Using container: \(container.containerIdentifier ?? "unknown")")
        print("🔍 ALT QUERY: Database type: \(privateDatabase.databaseScope.rawValue) (0=Private, 1=Public, 2=Shared)")
        
        // Perform the query
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            if let error = error {
                print("❌ ALT QUERY ERROR: \(error.localizedDescription)")
                
                if let ckError = error as? CKError {
                    print("🔍 ALT QUERY: CKError code: \(ckError.code.rawValue)")
                    print("🔍 ALT QUERY: Error details: \(ckError.localizedDescription)")
                    
                    if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                        print("🔍 ALT QUERY: Network issue with CloudKit")
                    } else if ckError.code == .serverRejectedRequest {
                        print("🔍 ALT QUERY: Server rejected request - possible permission issue")
                    } else if ckError.code == .zoneBusy {
                        print("🔍 ALT QUERY: Zone is busy, retry later")
                    }
                }
                
                completion(nil, error)
                return
            }
            
            guard let records = records, !records.isEmpty else {
                print("🔍 ALT QUERY: No locked document records found")
                // Clear the local set since there are no locked documents
                self.lockedDocuments.removeAll()
                completion(nil, nil)
                return
            }
            
            print("🔍 ALT QUERY: Found \(records.count) records matching query")
            print("🔍 ALT QUERY: Record types found: \(Set(records.map { $0.recordType }).joined(separator: ", "))")
            print("🔍 ALT QUERY: Record IDs found: \(records.map { $0.recordID.recordName }.joined(separator: ", "))")
            
            // Find the all_device_locks record if possible
            if let mainRecord = records.first(where: { $0.recordID.recordName == "all_device_locks" }) {
                print("🔍 ALT QUERY: Found main 'all_device_locks' record")
                print("🔍 ALT QUERY: Keys in main record: \(mainRecord.allKeys().joined(separator: ", "))")
                
                if let lockedDocsArray = mainRecord["lockedDocuments"] as? [String] {
                    print("🔍 ALT QUERY: Found \(lockedDocsArray.count) locked document IDs in main record")
                    
                    // Print each document ID for debugging
                    print("🔍 ALT QUERY RAW DATA: Document IDs in main record:")
                    for docId in lockedDocsArray {
                        print("   - \(docId)")
                    }
                    
                    let documentDisplayNames = lockedDocsArray.map { self.getDocumentDisplayName(for: $0) }
                    print("🔍 ALT QUERY: Found main lock record with locked documents: \(documentDisplayNames.joined(separator: ", "))")
                    
                    // Update the lockedDocuments set with UUIDs converted from strings
                    let oldSet = self.lockedDocuments
                    let newSet = Set(lockedDocsArray.compactMap { UUID(uuidString: $0) })
                    
                    // Log details about the conversion process
                    print("🔍 ALT QUERY: Converted \(newSet.count) of \(lockedDocsArray.count) strings to valid UUIDs")
                    
                    if newSet.count != lockedDocsArray.count {
                        print("⚠️ ALT QUERY: Some document IDs could not be converted to valid UUIDs:")
                        for docId in lockedDocsArray {
                            if UUID(uuidString: docId) == nil {
                                print("   ❌ Invalid UUID format: \(docId)")
                            }
                        }
                    }
                    
                    self.lockedDocuments = newSet
                    
                    // Log what documents have been added or removed
                    let addedDocs = newSet.subtracting(oldSet)
                    let removedDocs = oldSet.subtracting(newSet)
                    
                    print("🔍 ALT QUERY CHANGES: \(addedDocs.count) docs being added, \(removedDocs.count) docs being removed")
                    
                    if !addedDocs.isEmpty {
                        print("🔍 ALT QUERY ADDED: Documents being added to locked state:")
                        for docId in addedDocs {
                            let docName = self.getDocumentDisplayName(for: docId.uuidString)
                            print("   + '\(docName)' (\(docId))")
                        }
                    }
                    
                    if !removedDocs.isEmpty {
                        print("🔍 ALT QUERY REMOVED: Documents being removed from locked state:")
                        for docId in removedDocs {
                            let docName = self.getDocumentDisplayName(for: docId.uuidString) 
                            print("   - '\(docName)' (\(docId))")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentLocksChanged"), object: nil)
                    }
                    
                    completion(lockedDocsArray, nil)
                    return
                } else {
                    print("⚠️ ALT QUERY: Found main record but it has no 'lockedDocuments' field or it's not an array")
                }
            } else {
                print("⚠️ ALT QUERY: Main 'all_device_locks' record not found among results")
            }
            
            // Process all records if we couldn't find the main one
            print("🔍 ALT QUERY: Processing all \(records.count) records to collect locked documents")
            var lockedDocumentsFromCloud: [String] = []
            
            for record in records {
                print("🔍 ALT QUERY: Processing record: \(record.recordID.recordName), keys: \(record.allKeys().joined(separator: ", "))")
                if let lockedDocsArray = record["lockedDocuments"] as? [String] {
                    print("🔍 ALT QUERY: Found \(lockedDocsArray.count) document IDs in record \(record.recordID.recordName)")
                    lockedDocumentsFromCloud.append(contentsOf: lockedDocsArray)
                }
            }
            
            if !lockedDocumentsFromCloud.isEmpty {
                print("🔍 ALT QUERY: Combined \(lockedDocumentsFromCloud.count) locked document IDs from all records")
                
                // Print combined document IDs for debugging
                print("🔍 ALT QUERY COMBINED DATA: All document IDs from all records:")
                for docId in lockedDocumentsFromCloud {
                    print("   - \(docId)")
                }
                
                let oldSet = self.lockedDocuments
                let newSet = Set(lockedDocumentsFromCloud.compactMap { UUID(uuidString: $0) })
                
                print("🔍 ALT QUERY: Converted \(newSet.count) of \(lockedDocumentsFromCloud.count) strings to valid UUIDs")
                
                let documentDisplayNames = lockedDocumentsFromCloud.map { self.getDocumentDisplayName(for: $0) }
                print("🔍 ALT QUERY: Found documents from multiple records: \(documentDisplayNames.joined(separator: ", "))")
                
                // Update the lockedDocuments set with UUIDs converted from strings
                self.lockedDocuments = newSet
                
                // Log what documents have been added or removed
                let addedDocs = newSet.subtracting(oldSet)
                let removedDocs = oldSet.subtracting(newSet)
                
                print("🔍 ALT QUERY CHANGES: \(addedDocs.count) docs being added, \(removedDocs.count) docs being removed")
                
                if !addedDocs.isEmpty {
                    print("🔍 ALT QUERY ADDED: Documents being added to locked state:")
                    for docId in addedDocs {
                        let docName = self.getDocumentDisplayName(for: docId.uuidString)
                        print("   + '\(docName)' (\(docId))")
                    }
                }
                
                if !removedDocs.isEmpty {
                    print("🔍 ALT QUERY REMOVED: Documents being removed from locked state:")
                    for docId in removedDocs {
                        let docName = self.getDocumentDisplayName(for: docId.uuidString)
                        print("   - '\(docName)' (\(docId))")
                    }
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentLocksChanged"), object: nil)
                }
                
                completion(lockedDocumentsFromCloud, nil)
            } else {
                print("⚠️ ALT QUERY: No valid locked documents found in any records")
                // Clear the local set since there are no locked documents
                self.lockedDocuments.removeAll()
                completion([], nil)
            }
        }
    }
    
    /// Subscribe to changes in locked documents
    func subscribeToChanges(completion: @escaping (Error?) -> Void) {
        // Skip if cloud is not available
        guard isCloudAvailable else {
            log("iCloud not available, skipping subscription setup", level: .warning)
            completion(NSError(domain: "CloudSyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"]))
            return
        }
        
        log("Setting up CloudKit subscription for document locks", level: .info)
        
        // Create a dummy record if none exists yet
        let dummyRecordID = CKRecord.ID(recordName: "dummy_lock_record")
        let dummyRecord = CKRecord(recordType: self.lockRecordType, recordID: dummyRecordID)
        dummyRecord["lockedDocuments"] = [] as CKRecordValue
        dummyRecord["updatedAt"] = Date() as CKRecordValue
        dummyRecord["deviceId"] = deviceId as CKRecordValue
        
        // Don't rely on lockIdentifier field if it's not in the schema
        log("Saving dummy record to ensure type exists", level: .debug)
        self.privateDatabase.save(dummyRecord) { (savedRecord, error) in
            if let error = error {
                // If the error is just that the record already exists, that's fine
                if let ckError = error as? CKError, 
                   ckError.code == .serverRecordChanged || 
                   ckError.errorUserInfo["NSLocalizedDescription"] as? String == "record to insert already exists" {
                    self.log("Dummy record already exists", level: .info)
                } else {
                    self.log("Error saving dummy record: \(error.localizedDescription)", level: .warning)
                    // Non-critical error, continue anyway
                }
            } else {
                self.log("Successfully saved dummy record", level: .info)
            }
            
            // Now check if subscription already exists
            let subscriptionID = "document_lock_changes"
            
            self.privateDatabase.fetch(withSubscriptionID: subscriptionID) { (subscription, error) in
                if subscription != nil {
                    self.log("Subscription already exists", level: .info)
                    completion(nil)
                    return
                }
                
                // Create subscription for any changes to the lock record type 
                // Use a simple predicate that doesn't rely on lockIdentifier
                let predicate = NSPredicate(value: true)
                let subscription = CKQuerySubscription(
                    recordType: self.lockRecordType,
                    predicate: predicate,
                    subscriptionID: subscriptionID,
                    options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
                )
                
                let notificationInfo = CKSubscription.NotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                // This ensures silent background updates
                subscription.notificationInfo = notificationInfo
                
                self.privateDatabase.save(subscription) { (_, error) in
                    if let error = error {
                        self.log("Error creating subscription: \(error.localizedDescription)", level: .error)
                        completion(error)
                        return
                    }
                    
                    self.log("Successfully subscribed to lock changes", level: .info)
                    
                    // After subscription setup, do an initial fetch to sync current state
                    self.fetchLockedDocuments { (documents, error) in
                        if let error = error {
                            self.log("Initial fetch after subscription setup failed: \(error.localizedDescription)", level: .warning)
                        } else {
                            self.log("Initial subscription data fetch complete", level: .info)
                        }
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupSubscriptionIfNeeded() {
        // Skip subscription setup in simulator - not needed
        if isRunningInSimulator {
            log("Simulator: Skipping CloudKit subscription setup", level: .debug)
            return
        }
        
        subscribeToChanges { error in
            if let error = error {
                self.log("Failed to set up subscription: \(error.localizedDescription)", level: .warning)
            }
        }
    }
    
    private func getAllLockedDocumentsFromService() -> [String]? {
        // Get all locked documents from UserDefaults
        if let lockedDocumentStrings = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") {
            // Also update the local Set of UUIDs
            lockedDocuments = Set(lockedDocumentStrings.compactMap { UUID(uuidString: $0) })
            return lockedDocumentStrings
        }
        return nil
    }
    
    // Function to toggle verbose logging
    func setVerboseLogging(_ enabled: Bool) {
        isVerboseLogging = enabled
        log("Verbose logging \(enabled ? "enabled" : "disabled")", level: .info)
    }
    
    // Add debug-only logging for CloudKit issues
    public func toggleCloudDebugLogging(_ enabled: Bool) {
        isVerboseLogging = enabled
        log("CloudKit debug logging \(enabled ? "enabled" : "disabled")", level: .info)
        
        // Force an immediate check of iCloud availability with logging
        if enabled {
            log("Running diagnostics check now...", level: .info)
            checkCloudAvailability()
        }
    }
    
    func isLocked(_ documentId: UUID) -> Bool {
        let isLocked = lockedDocuments.contains(documentId)
        
        // Only log each document's status once per minute
        let now = Date()
        if lastLoggedTime[documentId] == nil || 
           now.timeIntervalSince(lastLoggedTime[documentId]!) > 60 {
            let documentName = getDocumentDisplayName(for: documentId.uuidString)
            print("🔒 Checking if document '\(documentName)' is locked: \(isLocked)")
            lastLoggedTime[documentId] = now
        }
        
        return isLocked
    }
    
    // Method to load document locks from local storage as a fallback
    private func loadLockedDocumentsFromLocalStorage() {
        print("📂 Attempting to load document locks from local storage")
        
        if let lockedDocStrings = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") {
            let previousCount = lockedDocuments.count
            let localDocs = Set(lockedDocStrings.compactMap { UUID(uuidString: $0) })
            
            lockedDocuments = localDocs
            
            print("📂 Loaded \(lockedDocuments.count) document locks from local storage (was \(previousCount))")
            
            // Print details of locked documents for debugging
            print("🔒 Currently locked documents from local storage:")
            for docId in lockedDocuments {
                let docName = self.getDocumentDisplayName(for: docId.uuidString)
                print("  - '\(docName)' (\(docId))")
            }
            
            // Notify about the change to update UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("DocumentLocksChanged"), object: nil)
            }
        } else {
            print("📂 No document locks found in local storage")
        }
    }
} 
