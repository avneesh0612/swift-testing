//
//  WalletView.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift
import AnyCodableSwift

struct WalletView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @State private var selectedChain: ChainType = .evm
    @State private var showNetworkPicker = false
    
    enum ChainType: String, CaseIterable {
        case evm = "EVM"
        case solana = "Solana"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Chain Selector
                    Picker("Chain", selection: $selectedChain) {
                        ForEach(ChainType.allCases, id: \.self) { chain in
                            Text(chain.rawValue).tag(chain)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedChain {
                    case .evm:
                        EVMWalletsSection(dynamicManager: dynamicManager)
                    case .solana:
                        SolanaWalletsSection(dynamicManager: dynamicManager)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showNetworkPicker = true }) {
                        Image(systemName: "network")
                    }
                }
            }
            .sheet(isPresented: $showNetworkPicker) {
                NetworkPickerView(dynamicManager: dynamicManager)
            }
        }
    }
}

struct EVMWalletsSection: View {
    @ObservedObject var dynamicManager: DynamicManager
    
    var evmWallets: [BaseWallet] {
        dynamicManager.getEVMWallets()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if evmWallets.isEmpty {
                EmptyWalletView(chainName: "EVM")
            } else {
                ForEach(evmWallets, id: \.address) { wallet in
                    EVMWalletCard(wallet: wallet, dynamicManager: dynamicManager)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct EVMWalletCard: View {
    let wallet: BaseWallet
    @ObservedObject var dynamicManager: DynamicManager
    @State private var balance: String = "..."
    @State private var isLoadingBalance = false
    @State private var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "diamond.fill")
                    .font(.title2)
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.walletName ?? "EVM Wallet")
                        .font(.headline)
                    Text("Ethereum Compatible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if isLoadingBalance {
                        ProgressView()
                    } else {
                        Text("\(balance) ETH")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    if let network = dynamicManager.currentNetwork {
                        Text(network.name)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            HStack {
                Text(formatAddress(wallet.address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { copyAddress() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            .padding(10)
            .background(Color(.systemGray5))
            .cornerRadius(8)

            HStack(spacing: 12) {
                NavigationLink(destination: SendTransactionView(
                    dynamicManager: dynamicManager,
                    wallet: wallet
                )) {
                    ActionButton(icon: "arrow.up.circle", title: "Send", color: .blue)
                }
                NavigationLink(destination: SignMessageView(
                    dynamicManager: dynamicManager,
                    wallet: wallet
                )) {
                    ActionButton(icon: "signature", title: "Sign", color: .purple)
                }
                Button(action: { refreshBalance() }) {
                    ActionButton(icon: "arrow.clockwise", title: "Refresh", color: .green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear { refreshBalance() }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = wallet.address
    }
    
    private func refreshBalance() {
        isLoadingBalance = true
        Task {
            do {
                let newBalance = try await dynamicManager.getWalletBalance(wallet: wallet)
                await MainActor.run {
                    balance = newBalance
                    isLoadingBalance = false
                }
            } catch {
                await MainActor.run {
                    balance = "Error"
                    isLoadingBalance = false
                }
            }
        }
    }
}

struct SolanaWalletsSection: View {
    @ObservedObject var dynamicManager: DynamicManager
    
    var solanaWallets: [BaseWallet] {
        dynamicManager.getSolanaWallets()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if solanaWallets.isEmpty {
                EmptyWalletView(chainName: "Solana")
            } else {
                ForEach(solanaWallets, id: \.address) { wallet in
                    SolanaWalletCard(wallet: wallet, dynamicManager: dynamicManager)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SolanaWalletCard: View {
    let wallet: BaseWallet
    @ObservedObject var dynamicManager: DynamicManager
    @State private var balance: String = "..."
    @State private var isLoadingBalance = false
    @State private var selectedCluster: SolanaClusterConfig = .devnet
    @State private var tokens: [SolanaToken] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.walletName ?? "Solana Wallet")
                        .font(.headline)
                    Text("Solana Network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if isLoadingBalance {
                        ProgressView()
                    } else {
                        Text("\(balance) SOL")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    Text(selectedCluster.rawValue)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            HStack {
                Text(formatAddress(wallet.address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { copyAddress() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            .padding(10)
            .background(Color(.systemGray5))
            .cornerRadius(8)

            if !tokens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tokens (\(tokens.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tokens.prefix(5)) { token in
                                HStack(spacing: 4) {
                                    if token.isNative {
                                        Image(systemName: "circle.hexagongrid.fill")
                                            .foregroundColor(.purple)
                                            .font(.caption)
                                    } else {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                    Text("\(token.formattedBalance) \(token.symbol)")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                NavigationLink(destination: SolanaSendView(
                    dynamicManager: dynamicManager,
                    wallet: wallet
                )) {
                    ActionButton(icon: "arrow.up.circle", title: "Send", color: .purple)
                }
                NavigationLink(destination: SolanaSignView(
                    dynamicManager: dynamicManager,
                    wallet: wallet
                )) {
                    ActionButton(icon: "signature", title: "Sign", color: .pink)
                }
                NavigationLink(destination: SolanaTokensView(
                    dynamicManager: dynamicManager,
                    wallet: wallet
                )) {
                    ActionButton(icon: "list.bullet", title: "Tokens", color: .orange)
                }
                Button(action: { refreshBalance() }) {
                    ActionButton(icon: "arrow.clockwise", title: "Refresh", color: .green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear { refreshBalance() }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func copyAddress() {
        UIPasteboard.general.string = wallet.address
    }

    private func refreshBalance() {
        isLoadingBalance = true
        Task {
            do {
                let fetchedTokens = try await dynamicManager.getSolanaTokenBalances(
                    wallet: wallet,
                    cluster: selectedCluster
                )
                await MainActor.run {
                    tokens = fetchedTokens
                    if let solToken = fetchedTokens.first(where: { $0.isNative }) {
                        balance = solToken.formattedBalance
                    } else {
                        balance = "0"
                    }
                    isLoadingBalance = false
                }
            } catch {
                await MainActor.run {
                    balance = "Error"
                    isLoadingBalance = false
                }
            }
        }
    }
}

struct SolanaTokensView: View {
    @ObservedObject var dynamicManager: DynamicManager
    let wallet: BaseWallet
    @State private var tokens: [SolanaToken] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCluster: SolanaClusterConfig = .devnet

    var body: some View {
        List {
            Section {
                Picker("Cluster", selection: $selectedCluster) {
                    ForEach(SolanaClusterConfig.allCases, id: \.self) { cluster in
                        Text(cluster.rawValue).tag(cluster)
                    }
                }
                .pickerStyle(.segmented)
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading tokens...")
                        Spacer()
                    }
                }
            } else if let error = error {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            loadTokens()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else if tokens.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Tokens Found")
                            .font(.headline)
                        Text("You don't have any tokens on \(selectedCluster.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                let nativeTokens = tokens.filter { $0.isNative }
                if !nativeTokens.isEmpty {
                    Section("Native Token") {
                        ForEach(nativeTokens) { token in
                            SolanaTokenListRow(token: token)
                        }
                    }
                }

                let splTokens = tokens.filter { !$0.isNative }
                if !splTokens.isEmpty {
                    Section("SPL Tokens (\(splTokens.count))") {
                        ForEach(splTokens) { token in
                            SolanaTokenListRow(token: token)
                        }
                    }
                }
            }
        }
        .navigationTitle("Solana Tokens")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: loadTokens) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            loadTokens()
        }
        .onChange(of: selectedCluster) { _ in
            loadTokens()
        }
    }

    private func loadTokens() {
        isLoading = true
        error = nil

        Task {
            do {
                let fetchedTokens = try await dynamicManager.getSolanaTokenBalances(
                    wallet: wallet,
                    cluster: selectedCluster
                )
                await MainActor.run {
                    tokens = fetchedTokens
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

struct SolanaTokenListRow: View {
    let token: SolanaToken

    var body: some View {
        HStack(spacing: 12) {
            if let logoUrl = token.logo, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    tokenIcon
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                tokenIcon
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(token.symbol)
                    .font(.headline)
                Text(token.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !token.isNative {
                    Text(formatMintAddress(token.mintAddress))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(token.formattedBalance)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(token.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var tokenIcon: some View {
        ZStack {
            Circle()
                .fill(token.isNative ? Color.purple.opacity(0.2) : Color.orange.opacity(0.2))
            Image(systemName: token.isNative ? "circle.hexagongrid.fill" : "dollarsign.circle.fill")
                .font(.title2)
                .foregroundColor(token.isNative ? .purple : .orange)
        }
    }

    private func formatMintAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

struct EmptyWalletView: View {
    let chainName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No \(chainName) Wallets")
                .font(.headline)
            Text("Wallets are automatically created when you sign in. Enable \(chainName) wallets in your Dynamic dashboard.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(10)
    }
}

struct NetworkPickerView: View {
    @ObservedObject var dynamicManager: DynamicManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedIndex: Int?
    @State private var isSwitching = false
    @State private var error: String?
    
    var evmNetworks: [GenericNetwork] {
        dynamicManager.getEVMNetworks()
    }
    
    var body: some View {
        NavigationStack {
            List {
                if evmNetworks.isEmpty {
                    Section {
                        Text("No networks available")
                            .foregroundColor(.secondary)
                        Text("Configure EVM networks in your Dynamic dashboard.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Available Networks") {
                        ForEach(Array(evmNetworks.enumerated()), id: \.offset) { index, network in
                            Button(action: { selectNetwork(network, at: index) }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(network.vanityName ?? network.name)
                                            .font(.headline)
                                        Text(network.nativeCurrency.symbol)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedIndex == index {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
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
            .navigationTitle("Select Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isSwitching {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Switching Network...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func selectNetwork(_ network: GenericNetwork, at index: Int) {
        guard let wallet = dynamicManager.getEVMWallets().first else {
            error = "No EVM wallet available"
            return
        }
        
        // Get chainId from network - it's AnyCodable so we need to extract it
        guard let chainIdValue = network.chainId.value as? Int else {
            error = "Invalid chain ID"
            return
        }
        
        isSwitching = true
        error = nil
        
        Task {
            do {
                try await dynamicManager.switchNetwork(wallet: wallet, chainId: chainIdValue)
                await MainActor.run {
                    selectedIndex = index
                    isSwitching = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSwitching = false
                }
            }
        }
    }
}

#Preview {
    WalletView(dynamicManager: DynamicManager.shared)
}
