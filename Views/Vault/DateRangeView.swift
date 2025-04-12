import SwiftUI

// Date range view for VaultView
struct DateRangeView: View {
    @ObservedObject var viewModel: VaultViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
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