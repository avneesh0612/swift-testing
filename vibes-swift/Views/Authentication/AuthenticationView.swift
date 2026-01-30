//
//  AuthenticationView.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift

struct AuthenticationView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var selectedAuthMethod: AuthMethod = .email
    
    enum AuthMethod: String, CaseIterable {
        case email = "Email"
        case phone = "Phone"
        case social = "Social"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Vibes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Your Web3 Gateway")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    Picker("Authentication Method", selection: $selectedAuthMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(spacing: 20) {
                        switch selectedAuthMethod {
                        case .email:
                            EmailAuthView(dynamicManager: dynamicManager)
                        case .phone:
                            PhoneAuthView(dynamicManager: dynamicManager)
                        case .social:
                            SocialAuthView(dynamicManager: dynamicManager)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    if let error = dynamicManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EmailAuthView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var email = ""
    @State private var otpCode = ""
    @State private var showOTPInput = false
    @State private var localError: String?
    
    var body: some View {
        VStack(spacing: 16) {
            if !showOTPInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                        TextField("Enter your email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: sendOTP) {
                    HStack {
                        if dynamicManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send OTP")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || dynamicManager.isLoading)

            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: { showOTPInput = false }) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    Text("Enter OTP sent to \(email)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                        TextField("Enter 6-digit code", text: $otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: verifyOTP) {
                    HStack {
                        if dynamicManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify & Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(otpCode.count < 6 ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(otpCode.count < 6 || dynamicManager.isLoading)
                
                Button("Resend OTP") {
                    sendOTP()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let error = localError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func sendOTP() {
        localError = nil
        Task {
            do {
                try await dynamicManager.sendEmailOTP(email: email)
                showOTPInput = true
            } catch {
                localError = error.localizedDescription
            }
        }
    }
    
    private func verifyOTP() {
        localError = nil
        Task {
            do {
                try await dynamicManager.verifyEmailOTP(code: otpCode)
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

struct PhoneAuthView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var phoneNumber = ""
    @State private var countryCode = "1"
    @State private var otpCode = ""
    @State private var showOTPInput = false
    @State private var localError: String?
    
    var body: some View {
        VStack(spacing: 16) {
            if !showOTPInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.secondary)
                        TextField("+1", text: $countryCode)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                        TextField("(555) 123-4567", text: $phoneNumber)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: sendOTP) {
                    HStack {
                        if dynamicManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send OTP")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(phoneNumber.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(phoneNumber.isEmpty || dynamicManager.isLoading)

            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: { showOTPInput = false }) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    Text("Enter OTP sent to +\(countryCode) \(phoneNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                        TextField("Enter 6-digit code", text: $otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: verifyOTP) {
                    HStack {
                        if dynamicManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify & Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(otpCode.count < 6 ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(otpCode.count < 6 || dynamicManager.isLoading)
                
                Button("Resend OTP") {
                    sendOTP()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let error = localError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func sendOTP() {
        localError = nil
        Task {
            do {
                try await dynamicManager.sendSMSOTP(phoneNumber: phoneNumber, countryCode: countryCode)
                showOTPInput = true
            } catch {
                localError = error.localizedDescription
            }
        }
    }
    
    private func verifyOTP() {
        localError = nil
        Task {
            do {
                try await dynamicManager.verifySMSOTP(code: otpCode)
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

struct SocialAuthView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var localError: String?
    @State private var loadingProvider: SocialProvider?
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Sign in with")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SocialButton(
                title: "Continue with Google",
                icon: "globe",
                color: .red,
                isLoading: loadingProvider == .google
            ) {
                handleSocialLogin(.google)
            }

            SocialButton(
                title: "Continue with Apple",
                icon: "apple.logo",
                color: .primary,
                isLoading: loadingProvider == .apple
            ) {
                handleSocialLogin(.apple)
            }

            Divider()
                .padding(.vertical, 8)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SocialIconButton(icon: "bird", color: .blue, isLoading: loadingProvider == .twitter) {
                    handleSocialLogin(.twitter)
                }
                SocialIconButton(icon: "bubble.left.and.bubble.right", color: .purple, isLoading: loadingProvider == .discord) {
                    handleSocialLogin(.discord)
                }
                SocialIconButton(icon: "chevron.left.forwardslash.chevron.right", color: .gray, isLoading: loadingProvider == .github) {
                    handleSocialLogin(.github)
                }
                SocialIconButton(icon: "f.cursive", color: .purple, isLoading: loadingProvider == .farcaster) {
                    handleSocialLogin(.farcaster)
                }
            }

            if let error = localError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }

    private func handleSocialLogin(_ provider: SocialProvider) {
        localError = nil
        loadingProvider = provider

        Task {
            do {
                try await dynamicManager.socialLogin(provider: provider)
            } catch {
                localError = error.localizedDescription
            }
            loadingProvider = nil
        }
    }
}

struct SocialButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

struct SocialIconButton: View {
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
        }
        .frame(width: 50, height: 50)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .disabled(isLoading)
    }
}

#Preview {
    AuthenticationView(dynamicManager: DynamicManager.shared)
}
