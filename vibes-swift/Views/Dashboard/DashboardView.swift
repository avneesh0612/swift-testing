//
//  DashboardView.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift

struct DashboardView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var selectedTab: Tab = .wallets
    
    enum Tab: String, CaseIterable {
        case wallets = "Wallets"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .wallets: return "wallet.pass"
            case .profile: return "person.circle"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WalletView(dynamicManager: dynamicManager)
                .tabItem {
                    Label(Tab.wallets.rawValue, systemImage: Tab.wallets.icon)
                }
                .tag(Tab.wallets)
            
            ProfileView(dynamicManager: dynamicManager)
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.purple)
    }
}

struct ProfileView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                if let user = dynamicManager.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 60, height: 60)
                                
                                Text(getInitials(from: user))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let email = user.email {
                                    Text(email)
                                        .font(.headline)
                                }
                                
                                if let userId = user.userId {
                                    Text("User ID: \(String(userId.prefix(8)))...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Wallets") {
                        HStack {
                            Label("EVM Wallets", systemImage: "diamond.fill")
                            Spacer()
                            Text("\(dynamicManager.getEVMWallets().count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Solana Wallets", systemImage: "circle.hexagongrid.fill")
                            Spacer()
                            Text("\(dynamicManager.getSolanaWallets().count)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Settings") {
                        NavigationLink(destination: SecuritySettingsView(dynamicManager: dynamicManager)) {
                            Label("Security", systemImage: "lock.shield")
                        }
                        
                        NavigationLink(destination: NetworkSettingsView(dynamicManager: dynamicManager)) {
                            Label("Networks", systemImage: "network")
                        }
                        
                        NavigationLink(destination: AboutView()) {
                            Label("About", systemImage: "info.circle")
                        }
                    }

                    Section("Debug") {
                        Button(action: {
                            dynamicManager.showUserProfile()
                        }) {
                            Label("Open Dynamic Widget", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                        }
                    }

                    Section {
                        Button(role: .destructive, action: { showLogoutConfirmation = true }) {
                            HStack {
                                Spacer()
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Not Signed In",
                        systemImage: "person.slash",
                        description: "Sign in to view your profile"
                    )
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await dynamicManager.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func getInitials(from user: UserProfile) -> String {
        if let email = user.email {
            return String(email.prefix(2)).uppercased()
        }
        return "U"
    }
}

struct SecuritySettingsView: View {
    @ObservedObject var dynamicManager: DynamicManager
    
    var body: some View {
        List {
            Section("Authentication") {
                HStack {
                    Label("Login Method", systemImage: "key")
                    Spacer()
                    Text("Email OTP")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Wallet Security") {
                HStack {
                    Label("MPC Wallet", systemImage: "lock.shield.fill")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Text("Your wallet keys are secured using Multi-Party Computation (MPC) technology. No single party has access to your complete private key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Advanced") {
                NavigationLink(destination: MFASettingsView(dynamicManager: dynamicManager)) {
                    Label("MFA Settings", systemImage: "shield.checkered")
                }
                
                NavigationLink(destination: PasskeySettingsView(dynamicManager: dynamicManager)) {
                    Label("Passkey Management", systemImage: "person.badge.key.fill")
                }
                
                NavigationLink(destination: RecoveryView(dynamicManager: dynamicManager)) {
                    Label("Recovery Options", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Security")
    }
}

struct MFASettingsView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var devices: [MfaDevice] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showTOTPSetup = false
    @State private var totpSecret: String?
    @State private var verificationCode = ""
    @State private var isVerifying = false
    
    var body: some View {
        List {
            Section("MFA Devices") {
                if isLoading {
                    ProgressView("Loading devices...")
                } else if devices.isEmpty {
                    Text("No MFA devices configured")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(devices, id: \.id) { device in
                        HStack {
                            Label(device.type?.rawValue ?? "TOTP", systemImage: "shield.checkered")
                            Spacer()
                            if device.verified == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            if showTOTPSetup, let secret = totpSecret {
                Section("Setup Authenticator") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add this secret to your authenticator app (Google Authenticator, Authy, etc.):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(secret)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = secret
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }

                Section("Verify Device") {
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    Button(action: verifyTOTP) {
                        if isVerifying {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Verify")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(verificationCode.count != 6 || isVerifying)
                    Button("Cancel", role: .destructive) {
                        cancelSetup()
                    }
                }
            } else {
                Section {
                    Button("Add TOTP Device") {
                        addTOTPDevice()
                    }
                    .disabled(isLoading)
                }
            }
            
            if let error = error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("MFA Settings")
        .onAppear {
            loadDevices()
        }
    }
    
    private func loadDevices() {
        isLoading = true
        Task {
            do {
                let fetchedDevices = try await dynamicManager.getMFADevices()
                await MainActor.run {
                    devices = fetchedDevices
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func addTOTPDevice() {
        isLoading = true
        error = nil
        Task {
            do {
                let device = try await dynamicManager.addTOTPDevice()
                await MainActor.run {
                    totpSecret = device.secret
                    showTOTPSetup = true
                    isLoading = false
                    loadDevices()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyTOTP() {
        isVerifying = true
        error = nil
        Task {
            do {
                try await dynamicManager.verifyTOTPDevice(code: verificationCode)
                await MainActor.run {
                    showTOTPSetup = false
                    totpSecret = nil
                    verificationCode = ""
                    isVerifying = false
                    loadDevices()
                }
            } catch {
                await MainActor.run {
                    self.error = "Invalid code. Please try again."
                    isVerifying = false
                }
            }
        }
    }
    
    private func cancelSetup() {
        showTOTPSetup = false
        totpSecret = nil
        verificationCode = ""
        error = nil
    }
}

struct PasskeySettingsView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var passkeys: [UserPasskey] = []
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        List {
            Section("Registered Passkeys") {
                if isLoading {
                    ProgressView("Loading passkeys...")
                } else if passkeys.isEmpty {
                    Text("No passkeys registered")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(passkeys, id: \.id) { passkey in
                        HStack {
                            Label(passkey.alias ?? "Passkey", systemImage: "person.badge.key.fill")
                            Spacer()
                        }
                    }
                }
            }
            
            Section {
                Button("Register New Passkey") {
                    registerPasskey()
                }
            }
            
            if let error = error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Passkeys")
        .onAppear { loadPasskeys() }
    }

    private func loadPasskeys() {
        isLoading = true
        Task {
            do {
                let fetchedPasskeys = try await dynamicManager.getPasskeys()
                await MainActor.run {
                    passkeys = fetchedPasskeys
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func registerPasskey() {
        Task {
            do {
                try await dynamicManager.registerPasskey()
                loadPasskeys()
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

struct NetworkSettingsView: View {
    @ObservedObject var dynamicManager: DynamicManager
    
    let evmNetworks = [
        ("Ethereum Mainnet", 1, true),
        ("Sepolia Testnet", 11155111, true),
        ("Polygon", 137, true),
        ("Polygon Amoy", 80002, true),
        ("Base", 8453, true),
        ("Base Sepolia", 84532, true),
        ("Arbitrum One", 42161, true),
        ("Optimism", 10, true)
    ]
    
    let solanaNetworks = [
        ("Mainnet Beta", true),
        ("Devnet", true),
        ("Testnet", false)
    ]
    
    var body: some View {
        List {
            Section("EVM Networks") {
                ForEach(evmNetworks, id: \.1) { network in
                    HStack {
                        Text(network.0)
                        Spacer()
                        if network.2 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Section("Solana Networks") {
                ForEach(solanaNetworks, id: \.0) { network in
                    HStack {
                        Text(network.0)
                        Spacer()
                        if network.1 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Section {
                Text("Network availability is configured in your Dynamic dashboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Networks")
    }
}

struct RecoveryView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var recoveryCodes: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Recovery Information")
                            .fontWeight(.bold)
                    }
                    Text("Your wallet is secured using Dynamic's MPC technology. Recovery options are managed through your Dynamic account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("Recovery Methods") {
                HStack {
                    Label("Email Recovery", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                HStack {
                    Label("Social Recovery", systemImage: "person.2")
                    Spacer()
                    Text("Available")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Recovery Codes") {
                if recoveryCodes.isEmpty {
                    Button("Generate Recovery Codes") {
                        generateRecoveryCodes()
                    }
                } else {
                    ForEach(recoveryCodes, id: \.self) { code in
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Recovery")
    }
    
    private func generateRecoveryCodes() {
        isLoading = true
        Task {
            do {
                let codes = try await dynamicManager.getRecoveryCodes(generateNew: true)
                await MainActor.run {
                    recoveryCodes = codes
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Vibes")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }
            
            Section("Powered By") {
                Link(destination: URL(string: "https://www.dynamic.xyz")!) {
                    HStack {
                        Label("Dynamic SDK", systemImage: "cube.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section("Resources") {
                Link(destination: URL(string: "https://www.dynamic.xyz/docs/swift/introduction")!) {
                    HStack {
                        Label("Documentation", systemImage: "book")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                
                Link(destination: URL(string: "https://github.com/dynamic-labs/swift-sdk-and-sample-app")!) {
                    HStack {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("About")
    }
}

#Preview {
    DashboardView(dynamicManager: DynamicManager.shared)
}
