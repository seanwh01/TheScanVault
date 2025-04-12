import SwiftUI

extension Views_Settings {
    struct SubscriptionView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        @Binding var isPresented: Bool
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current plan section
                        VStack(alignment: .center, spacing: 10) {
                            Text("Current Plan")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text(subscriptionManager.subscriptionName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(subscriptionManager.isPremium ? .green : .blue)
                            
                            if subscriptionManager.isPremium {
                                Text("Renews \(formattedRenewalDate)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Plan comparison
                        VStack(spacing: 20) {
                            Text("Plan Comparison")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            PlanComparisonView(isCurrentPlan: !subscriptionManager.isPremium, planName: "Free", price: "Free", features: [
                                "Basic document storage",
                                "Manual document classification",
                                "Limited cloud storage (1GB)",
                                "Basic search"
                            ])
                            
                            PlanComparisonView(isCurrentPlan: subscriptionManager.isPremium, planName: "Premium", price: "$9.99/month", features: [
                                "Unlimited document storage",
                                "AI document classification",
                                "Enhanced cloud storage (10GB)",
                                "Advanced search capabilities",
                                "Document sharing",
                                "Priority support"
                            ])
                        }
                        .padding(.horizontal)
                        
                        // Action buttons
                        VStack(spacing: 16) {
                            if subscriptionManager.isPremium {
                                Button(action: manageBilling) {
                                    HStack {
                                        Image(systemName: "creditcard")
                                        Text("Manage Billing")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: cancelSubscription) {
                                    Text("Cancel Subscription")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.clear)
                                        .foregroundColor(.red)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.red, lineWidth: 1)
                                        )
                                }
                            } else {
                                Button(action: upgradeSubscription) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("Upgrade to Premium")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                        
                        // Terms and privacy
                        VStack(spacing: 8) {
                            Text("By subscribing, you agree to our Terms of Service and Privacy Policy.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            HStack {
                                Button(action: showTerms) {
                                    Text("Terms of Service")
                                        .font(.caption)
                                        .underline()
                                        .foregroundColor(.blue)
                                }
                                
                                Text("•")
                                    .foregroundColor(.gray)
                                
                                Button(action: showPrivacy) {
                                    Text("Privacy Policy")
                                        .font(.caption)
                                        .underline()
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .background(Color.black)
                .navigationTitle("Subscription")
                .navigationBarItems(trailing: Button("Close") {
                    isPresented = false
                })
            }
            .environment(\.colorScheme, .dark)
        }
        
        private var formattedRenewalDate: String {
            // In a real app, this would come from the subscription data
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            // Mock renewal date - 1 month from now
            let renewalDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            return formatter.string(from: renewalDate)
        }
        
        private func upgradeSubscription() {
            // In a real app, this would open the payment flow
            print("Upgrade subscription tapped")
        }
        
        private func cancelSubscription() {
            // In a real app, this would handle subscription cancellation
            print("Cancel subscription tapped")
        }
        
        private func manageBilling() {
            // In a real app, this would open billing management
            print("Manage billing tapped")
        }
        
        private func showTerms() {
            // In a real app, this would show terms of service
            print("Terms tapped")
        }
        
        private func showPrivacy() {
            // In a real app, this would show privacy policy
            print("Privacy tapped")
        }
    }
    
    // Helper view for plan comparison
    private struct PlanComparisonView: View {
        var isCurrentPlan: Bool
        var planName: String
        var price: String
        var features: [String]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(planName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if isCurrentPlan {
                        Text("Current")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrentPlan ? Color.blue : Color.gray.opacity(0.3), lineWidth: isCurrentPlan ? 2 : 1)
            )
        }
    }
} 