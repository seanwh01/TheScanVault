import SwiftUI

struct DatePickerSheet: View {
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
                .labelsHidden()
                .padding()
                
                Button("Done") {
                    isPresented = false
                    onComplete()
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
        }
    }
} 