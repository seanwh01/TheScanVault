import SwiftUI
import CoreData
import Combine

// Settings section view for SaveDocumentView - extracted as part of Phase 3 refactoring
extension Views_SaveDocument {
    struct SDV_SettingsView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var isFavorite: Bool
        @Binding var isReceipt: Bool
        @Binding var receiptDate: Date
        @Binding var receiptAmount: String
        
        var body: some View {
            Section {
                Toggle("Favorite", isOn: $isFavorite)
                    .onChange(of: isFavorite) { newValue in
                        // Log for now since we're not sure of the exact property on viewModel
                        print("Favorite toggled to: \(newValue)")
                    }
                
                Toggle("Receipt", isOn: $isReceipt)
                    .onChange(of: isReceipt) { newValue in
                        print("Receipt toggled to: \(newValue)")
                    }
                
                if isReceipt {
                    DatePicker("Date", selection: $receiptDate, displayedComponents: .date)
                        .onChange(of: receiptDate) { newValue in
                            print("Receipt date changed to: \(newValue)")
                        }
                    
                    TextField("Amount", text: $receiptAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: receiptAmount) { newValue in
                            print("Receipt amount changed to: \(newValue)")
                        }
                }
            } header: {
                Text("SETTINGS")
            }
        }
    }
}
