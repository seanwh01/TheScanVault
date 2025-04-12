import SwiftUI

extension Views_AIResearch {
    // Date range view
    struct AIDateRangeView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        
        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.white)
                        .frame(width: 20)
                    Text("From:")
                        .foregroundColor(.white)
                    Spacer()
                    Text(viewModel.fromDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.isSelectingFromDate = true
                    viewModel.showDatePicker = true
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.white)
                        .frame(width: 20)
                    Text("To:")
                        .foregroundColor(.white)
                    Spacer()
                    Text(viewModel.toDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.isSelectingFromDate = false
                    viewModel.showDatePicker = true
                }
            }
            .background(Color.blue.opacity(0.2))
            .cornerRadius(12)
        }
    }

    // Sheet for date picker
    struct AIDatePickerSheet: View {
        @Binding var date: Date
        @Binding var isPresented: Bool
        let title: String
        let onComplete: () -> Void
        
        var body: some View {
            NavigationView {
                VStack {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isPresented = false
                            onComplete()
                        }
                    }
                    
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
} 