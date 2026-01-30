//
//  SolanaViews.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift

struct SolanaSendView: View {
    @ObservedObject var dynamicManager: DynamicManager
    let wallet: BaseWallet

    @Environment(\.dismiss) var dismiss

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var isLoading = false
    @State private var transactionSignature: String?
    @State private var error: String?
    @State private var selectedCluster: SolanaClusterConfig = .devnet
    @State private var showClusterSelector = false
    @State private var showTokenSelector = false

    // Token state
    @State private var tokens: [SolanaToken] = []
    @State private var selectedToken: SolanaToken?
    @State private var isLoadingTokens = false
    @State private var tokenError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundColor(.purple)
                        Text(formatAddress(wallet.address))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(action: { UIPasteboard.general.string = wallet.address }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cluster")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: { showClusterSelector = true }) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.purple)
                            Text(selectedCluster.rawValue)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if isLoadingTokens {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    Button(action: { showTokenSelector = true }) {
                        HStack {
                            if let token = selectedToken {
                                if let logoUrl = token.logo, let url = URL(string: logoUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Image(systemName: token.isNative ? "circle.hexagongrid.fill" : "dollarsign.circle.fill")
                                            .foregroundColor(token.isNative ? .purple : .orange)
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: token.isNative ? "circle.hexagongrid.fill" : "dollarsign.circle.fill")
                                        .foregroundColor(token.isNative ? .purple : .orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token.symbol)
                                        .fontWeight(.medium)
                                    Text("Balance: \(token.formattedBalance)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.secondary)
                                Text("Select Token")
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .foregroundColor(.primary)
                    .disabled(isLoadingTokens)

                    if let tokenError = tokenError {
                        Text(tokenError)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("To Address")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.secondary)
                        TextField("Solana address...", text: $recipientAddress)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.secondary)
                        TextField("0.0", text: $amount)
                            .keyboardType(.decimalPad)
                        Text(selectedToken?.symbol ?? "SOL")
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)

                        if let token = selectedToken, Double(token.balance) ?? 0 > 0 {
                            Button("Max") {
                                amount = token.formattedBalance
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                if !recipientAddress.isEmpty && !amount.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Summary")
                            .font(.headline)

                        HStack {
                            Text("Amount:")
                            Spacer()
                            Text("\(amount) \(selectedToken?.symbol ?? "SOL")")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Token:")
                            Spacer()
                            Text(selectedToken?.name ?? "Solana")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Cluster:")
                            Spacer()
                            Text(selectedCluster.rawValue)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Fee (estimated):")
                            Spacer()
                            Text("~0.000005 SOL")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                if let signature = transactionSignature {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("Transaction Sent!")
                            .font(.headline)
                        Text("Signature: \(formatAddress(signature))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Copy Signature") {
                            UIPasteboard.general.string = signature
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        Button("View on Explorer") {
                            openExplorer(signature)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: sendTransaction) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send \(selectedToken?.symbol ?? "SOL")")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSend ? Color.purple : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSend || isLoading)

                if selectedCluster == .devnet {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.blue)
                            Text("Need Devnet SOL?")
                                .font(.headline)
                        }
                        Text("Get free devnet SOL from the Solana Faucet to test transactions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Open Solana Faucet") {
                            if let url = URL(string: "https://faucet.solana.com/") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showClusterSelector) {
            SolanaClusterSelectorSheet(selectedCluster: $selectedCluster)
        }
        .sheet(isPresented: $showTokenSelector) {
            SolanaTokenSelectorSheet(
                tokens: tokens,
                selectedToken: $selectedToken,
                isLoading: isLoadingTokens
            )
        }
        .onAppear {
            loadTokens()
        }
        .onChange(of: selectedCluster) { _ in
            loadTokens()
        }
    }

    private var canSend: Bool {
        !recipientAddress.isEmpty &&
        !amount.isEmpty &&
        recipientAddress.count >= 32 && recipientAddress.count <= 44 &&
        (Double(amount) ?? 0) > 0 &&
        selectedToken != nil
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func loadTokens() {
        isLoadingTokens = true
        tokenError = nil

        Task {
            do {
                let fetchedTokens = try await dynamicManager.getSolanaTokenBalances(
                    wallet: wallet,
                    cluster: selectedCluster
                )

                await MainActor.run {
                    tokens = fetchedTokens
                    if selectedToken == nil {
                        selectedToken = fetchedTokens.first { $0.isNative }
                            ?? fetchedTokens.first
                            ?? SolanaToken.nativeSOL()
                    }
                    isLoadingTokens = false
                }
            } catch {
                await MainActor.run {
                    let nativeToken = SolanaToken.nativeSOL()
                    tokens = [nativeToken]
                    selectedToken = nativeToken
                    tokenError = "Could not load tokens. Using native SOL only."
                    isLoadingTokens = false
                }
            }
        }
    }

    private func sendTransaction() {
        guard let token = selectedToken else { return }

        isLoading = true
        error = nil
        transactionSignature = nil

        Task {
            do {
                let signature: String

                if token.isNative {
                    signature = try await dynamicManager.sendSolanaTransaction(
                        wallet: wallet,
                        to: recipientAddress,
                        amount: amount,
                        cluster: selectedCluster
                    )
                } else {
                    signature = try await dynamicManager.sendSPLTokenTransfer(
                        wallet: wallet,
                        token: token,
                        to: recipientAddress,
                        amount: amount,
                        cluster: selectedCluster
                    )
                }

                await MainActor.run {
                    transactionSignature = signature
                    isLoading = false
                    loadTokens()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func openExplorer(_ signature: String) {
        var explorerUrl: String

        switch selectedCluster {
        case .mainnet:
            explorerUrl = "https://explorer.solana.com/tx/\(signature)"
        case .devnet:
            explorerUrl = "https://explorer.solana.com/tx/\(signature)?cluster=devnet"
        case .testnet:
            explorerUrl = "https://explorer.solana.com/tx/\(signature)?cluster=testnet"
        }

        if let url = URL(string: explorerUrl) {
            UIApplication.shared.open(url)
        }
    }
}

struct SolanaTokenSelectorSheet: View {
    let tokens: [SolanaToken]
    @Binding var selectedToken: SolanaToken?
    let isLoading: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("Loading tokens...")
                        Text("Fetching your token balances")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else if tokens.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("No tokens found")
                            .font(.headline)
                        Text("You don't have any tokens on this cluster")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        let nativeTokens = tokens.filter { $0.isNative }
                        if !nativeTokens.isEmpty {
                            Section("Native Token") {
                                ForEach(nativeTokens) { token in
                                    SolanaTokenRow(
                                        token: token,
                                        isSelected: selectedToken?.id == token.id
                                    ) {
                                        selectedToken = token
                                        dismiss()
                                    }
                                }
                            }
                        }

                        let splTokens = tokens.filter { !$0.isNative }
                        if !splTokens.isEmpty {
                            Section("SPL Tokens") {
                                ForEach(splTokens) { token in
                                    SolanaTokenRow(
                                        token: token,
                                        isSelected: selectedToken?.id == token.id
                                    ) {
                                        selectedToken = token
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SolanaTokenRow: View {
    let token: SolanaToken
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if let logoUrl = token.logo, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        tokenIcon
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    tokenIcon
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(token.symbol)
                        .font(.headline)
                    Text(token.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(token.formattedBalance)
                        .font(.headline)
                    if !token.isNative {
                        Text(formatAddress(token.mintAddress))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private var tokenIcon: some View {
        Image(systemName: token.isNative ? "circle.hexagongrid.fill" : "dollarsign.circle.fill")
            .font(.title2)
            .foregroundColor(token.isNative ? .purple : .orange)
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

struct SolanaClusterSelectorSheet: View {
    @Binding var selectedCluster: SolanaClusterConfig
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Testnets (Recommended for testing)") {
                    ForEach([SolanaClusterConfig.devnet, .testnet], id: \.self) { cluster in
                        Button(action: {
                            selectedCluster = cluster
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cluster.rawValue)
                                    Text(cluster.endpoint)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedCluster == cluster {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Mainnet") {
                    Button(action: {
                        selectedCluster = .mainnet
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(SolanaClusterConfig.mainnet.rawValue)
                                Text(SolanaClusterConfig.mainnet.endpoint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedCluster == .mainnet {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Cluster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SolanaSignView: View {
    @ObservedObject var dynamicManager: DynamicManager
    let wallet: BaseWallet
    
    @State private var message = ""
    @State private var signature: String?
    @State private var isLoading = false
    @State private var error: String?
    
    let exampleMessages = [
        "Hello, Solana!",
        "Verify wallet ownership",
        "Sign in to Vibes App",
        "Approve transaction"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signing Wallet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundColor(.purple)
                        Text(formatAddress(wallet.address))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Message to Sign")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    Text("Quick Examples:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(exampleMessages, id: \.self) { example in
                                Button(action: { message = example }) {
                                    Text(example)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.pink.opacity(0.2))
                                        .foregroundColor(.pink)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                }

                if let signature = signature {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Signature Generated")
                                .font(.headline)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(signature)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        Button(action: { UIPasteboard.general.string = signature }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Signature")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: signMessage) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "signature")
                            Text("Sign Message")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!message.isEmpty ? Color.pink : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(message.isEmpty || isLoading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("About Solana Signing")
                        .font(.headline)
                    Text("Solana message signing uses Ed25519 signatures to prove ownership of your wallet address.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Sign Message")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func signMessage() {
        isLoading = true
        error = nil
        signature = nil

        Task {
            do {
                let sig = try await dynamicManager.signMessage(wallet: wallet, message: message)
                await MainActor.run {
                    signature = sig
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
