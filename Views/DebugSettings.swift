import SwiftUI

struct DebugSettings: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Logging level options
    private let loggingLevels = [0, 1, 2, 3]
    
    // State for each logging option
    @AppStorage("com.apple.CoreData.CloudKitDebug") private var cloudKitDebugLevel = 0
    @AppStorage("com.apple.CoreData.Logging.stderr") private var coreDataLoggingLevel = 0
    @AppStorage("com.apple.CoreData.SQLDebug") private var sqlDebugLevel = 0
    
    // For showing confirmation alert
    @State private var showRestartAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("CoreData & CloudKit Logging")) {
                    // CloudKit Debug Level
                    VStack(alignment: .leading) {
                        Text("CloudKit Debug Level")
                            .font(.headline)
                        
                        Picker("CloudKit Debug Level", selection: $cloudKitDebugLevel) {
                            ForEach(loggingLevels, id: \.self) { level in
                                Text(level == 0 ? "Off" : "Level \(level)")
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: cloudKitDebugLevel) { _ in
                            UserDefaults.standard.set(cloudKitDebugLevel, forKey: "com.apple.CoreData.CloudKitDebug")
                            showRestartAlert = true
                        }
                        
                        Text("Controls verbosity of CloudKit sync logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // CoreData Logging Level
                    VStack(alignment: .leading) {
                        Text("CoreData Logging Level")
                            .font(.headline)
                        
                        Picker("CoreData Logging Level", selection: $coreDataLoggingLevel) {
                            ForEach(loggingLevels, id: \.self) { level in
                                Text(level == 0 ? "Off" : "Level \(level)")
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: coreDataLoggingLevel) { _ in
                            UserDefaults.standard.set(coreDataLoggingLevel, forKey: "com.apple.CoreData.Logging.stderr")
                            showRestartAlert = true
                        }
                        
                        Text("Controls verbosity of CoreData operation logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // SQL Debug Level
                    VStack(alignment: .leading) {
                        Text("SQL Debug Level")
                            .font(.headline)
                        
                        Picker("SQL Debug Level", selection: $sqlDebugLevel) {
                            ForEach(loggingLevels, id: \.self) { level in
                                Text(level == 0 ? "Off" : "Level \(level)")
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: sqlDebugLevel) { _ in
                            UserDefaults.standard.set(sqlDebugLevel, forKey: "com.apple.CoreData.SQLDebug")
                            showRestartAlert = true
                        }
                        
                        Text("Controls verbosity of SQL query logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Logging Actions")) {
                    Button(action: disableAllLogging) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Disable All Logging")
                        }
                    }
                    
                    Button(action: enableVerboseLogging) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Enable Verbose Logging")
                        }
                    }
                    
                    Button(action: setModerateLogs) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Set Moderate Logging")
                        }
                    }
                }
                
                Section(header: Text("About Logging Levels"), footer: Text("Changes to logging levels require restarting the app to take full effect")) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level 0")
                                .font(.subheadline)
                            Text("Disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level 1")
                                .font(.subheadline)
                            Text("Basic")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level 2")
                                .font(.subheadline)
                            Text("Detailed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level 3")
                                .font(.subheadline)
                            Text("Verbose")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Debug Logging")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showRestartAlert) {
                Alert(
                    title: Text("Logging Settings Updated"),
                    message: Text("Some logging changes might require restarting the app to take full effect."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                // Read current values when the view appears
                cloudKitDebugLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.CloudKitDebug")
                coreDataLoggingLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.Logging.stderr")
                sqlDebugLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.SQLDebug") 
                
                print("📝 Debug settings loaded - CloudKit: \(cloudKitDebugLevel), CoreData: \(coreDataLoggingLevel), SQL: \(sqlDebugLevel)")
            }
        }
    }
    
    // Helper functions to change logging levels
    private func disableAllLogging() {
        cloudKitDebugLevel = 0
        coreDataLoggingLevel = 0
        sqlDebugLevel = 0
        
        UserDefaults.standard.set(0, forKey: "com.apple.CoreData.CloudKitDebug")
        UserDefaults.standard.set(0, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(0, forKey: "com.apple.CoreData.SQLDebug")
        
        print("📝 All logging disabled")
        showRestartAlert = true
    }
    
    private func enableVerboseLogging() {
        cloudKitDebugLevel = 3
        coreDataLoggingLevel = 3
        sqlDebugLevel = 3
        
        UserDefaults.standard.set(3, forKey: "com.apple.CoreData.CloudKitDebug")
        UserDefaults.standard.set(3, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(3, forKey: "com.apple.CoreData.SQLDebug")
        
        print("📝 Verbose logging enabled")
        showRestartAlert = true
    }
    
    private func setModerateLogs() {
        cloudKitDebugLevel = 1
        coreDataLoggingLevel = 1 
        sqlDebugLevel = 1
        
        UserDefaults.standard.set(1, forKey: "com.apple.CoreData.CloudKitDebug")
        UserDefaults.standard.set(1, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")
        
        print("📝 Moderate logging enabled")
        showRestartAlert = true
    }
}

struct DebugSettings_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettings()
    }
} 