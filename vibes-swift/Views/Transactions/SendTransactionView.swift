//
//  SendTransactionView.swift
//  vibes-swift
//

import DynamicSDKSwift
import SwiftUI

struct SendTransactionView: View {
    @ObservedObject var dynamicManager: DynamicManager
    let wallet: BaseWallet

    @Environment(\.dismiss) var dismiss

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var selectedChainId: Int = 84532
    @State private var isLoading = false
    @State private var transactionHash: String?
    @State private var error: String?
    @State private var showNetworkSelector = false
    @State private var showTokenSelector = false

    // Token state
    @State private var tokens: [Token] = []
    @State private var selectedToken: Token?
    @State private var isLoadingTokens = false
    @State private var tokenError: String?

    let networks: [(String, Int)] = [
        ("Base Sepolia", 84532),
        ("Sepolia", 11_155_111),
        ("Polygon Amoy", 80002),
        ("Ethereum Mainnet", 1),
        ("Polygon", 137),
        ("Base", 8453),
        ("Arbitrum One", 42161),
        ("Optimism", 10),
    ]

    var selectedNetworkName: String {
        networks.first { $0.1 == selectedChainId }?.0 ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "wallet.pass.fill")
                            .foregroundColor(.blue)
                        Text(formatAddress(wallet.address))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Network")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: { showNetworkSelector = true }) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.purple)
                            Text(selectedNetworkName)
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
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                } else {
                                    Image(
                                        systemName: token.isNative
                                            ? "circle.hexagongrid.fill" : "dollarsign.circle.fill"
                                    )
                                    .foregroundColor(token.isNative ? .blue : .orange)
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
                        TextField("0x...", text: $recipientAddress)
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
                        Text(selectedToken?.symbol ?? "ETH")
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)

                        if let token = selectedToken, Double(token.balance) ?? 0 > 0 {
                            Button("Max") {
                                amount = token.formattedBalance
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
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
                            Text("\(amount) \(selectedToken?.symbol ?? "ETH")")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Token:")
                            Spacer()
                            Text(selectedToken?.name ?? "Native Token")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Network:")
                            Spacer()
                            Text(selectedNetworkName)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                if let hash = transactionHash {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("Transaction Sent!")
                            .font(.headline)
                        Text("Hash: \(formatAddress(hash))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Copy Hash") {
                            UIPasteboard.general.string = hash
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        Button("View on Explorer") {
                            openExplorer(hash)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
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
                            Text("Send \(selectedToken?.symbol ?? "Transaction")")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSend ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSend || isLoading)
            }
            .padding()
        }
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNetworkSelector) {
            NetworkSelectorSheet(
                selectedChainId: $selectedChainId,
                networks: networks
            )
        }
        .sheet(isPresented: $showTokenSelector) {
            TokenSelectorSheet(
                tokens: tokens,
                selectedToken: $selectedToken,
                isLoading: isLoadingTokens
            )
        }
        .onAppear {
            loadTokens()
        }
        .onChange(of: selectedChainId) { _ in
            loadTokens()
        }
    }

    private var canSend: Bool {
        !recipientAddress.isEmpty && !amount.isEmpty && recipientAddress.hasPrefix("0x")
            && recipientAddress.count == 42 && (Double(amount) ?? 0) > 0 && selectedToken != nil
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
                let fetchedTokens = try await dynamicManager.getTokenBalances(
                    wallet: wallet,
                    networkId: selectedChainId,
                    includeNative: true
                )

                await MainActor.run {
                    tokens = fetchedTokens
                    if selectedToken == nil || selectedToken?.chainId != selectedChainId {
                        selectedToken =
                            fetchedTokens.first { $0.isNative }
                            ?? fetchedTokens.first
                            ?? Token.native(for: selectedChainId)
                    }
                    isLoadingTokens = false
                }
            } catch {
                await MainActor.run {
                    let nativeToken = Token.native(for: selectedChainId)
                    tokens = [nativeToken]
                    selectedToken = nativeToken
                    tokenError = "Could not load tokens. Using native token only."
                    isLoadingTokens = false
                }
            }
        }
    }

    private func sendTransaction() {
        guard let token = selectedToken else { return }

        isLoading = true
        error = nil
        transactionHash = nil

        Task {
            do {
                let hash: String

                if token.isNative {
                    hash = try await dynamicManager.sendEVMTransaction(
                        wallet: wallet,
                        to: recipientAddress,
                        amount: amount,
                        chainId: selectedChainId
                    )
                } else {
                    hash = try await dynamicManager.sendERC20Transfer(
                        wallet: wallet,
                        token: token,
                        to: recipientAddress,
                        amount: amount,
                        chainId: selectedChainId
                    )
                }

                await MainActor.run {
                    transactionHash = hash
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

    private func openExplorer(_ hash: String) {
        var explorerUrl: String

        switch selectedChainId {
        case 1:
            explorerUrl = "https://etherscan.io/tx/\(hash)"
        case 11_155_111:
            explorerUrl = "https://sepolia.etherscan.io/tx/\(hash)"
        case 137:
            explorerUrl = "https://polygonscan.com/tx/\(hash)"
        case 80002:
            explorerUrl = "https://amoy.polygonscan.com/tx/\(hash)"
        case 8453:
            explorerUrl = "https://basescan.org/tx/\(hash)"
        case 84532:
            explorerUrl = "https://sepolia.basescan.org/tx/\(hash)"
        case 42161:
            explorerUrl = "https://arbiscan.io/tx/\(hash)"
        case 10:
            explorerUrl = "https://optimistic.etherscan.io/tx/\(hash)"
        default:
            explorerUrl = "https://etherscan.io/tx/\(hash)"
        }

        if let url = URL(string: explorerUrl) {
            UIApplication.shared.open(url)
        }
    }
}

struct TokenSelectorSheet: View {
    let tokens: [Token]
    @Binding var selectedToken: Token?
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
                        Text("You don't have any tokens on this network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        let nativeTokens = tokens.filter { $0.isNative }
                        if !nativeTokens.isEmpty {
                            Section("Native Token") {
                                ForEach(nativeTokens) { token in
                                    TokenRow(
                                        token: token, isSelected: selectedToken?.id == token.id
                                    ) {
                                        selectedToken = token
                                        dismiss()
                                    }
                                }
                            }
                        }

                        let erc20Tokens = tokens.filter { !$0.isNative }
                        if !erc20Tokens.isEmpty {
                            Section("ERC-20 Tokens") {
                                ForEach(erc20Tokens) { token in
                                    TokenRow(
                                        token: token, isSelected: selectedToken?.id == token.id
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

struct TokenRow: View {
    let token: Token
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if let logoUrl = token.logo, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.orange)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Image(
                        systemName: token.isNative
                            ? "circle.hexagongrid.fill" : "dollarsign.circle.fill"
                    )
                    .font(.title2)
                    .foregroundColor(token.isNative ? .blue : .orange)
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
                    if !token.isNative, let address = token.contractAddress {
                        Text(formatAddress(address))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct NetworkSelectorSheet: View {
    @Binding var selectedChainId: Int
    let networks: [(String, Int)]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Testnets (Recommended for testing)") {
                    ForEach(networks.filter { [84532, 11_155_111, 80002].contains($0.1) }, id: \.1)
                    { network in
                        Button(action: {
                            selectedChainId = network.1
                            dismiss()
                        }) {
                            HStack {
                                Text(network.0)
                                Spacer()
                                if selectedChainId == network.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Mainnets") {
                    ForEach(
                        networks.filter { ![84532, 11_155_111, 80002].contains($0.1) }, id: \.1
                    ) { network in
                        Button(action: {
                            selectedChainId = network.1
                            dismiss()
                        }) {
                            HStack {
                                Text(network.0)
                                Spacer()
                                if selectedChainId == network.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Select Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
