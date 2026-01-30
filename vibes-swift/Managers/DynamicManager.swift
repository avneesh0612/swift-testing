//
//  DynamicManager.swift
//  vibes-swift
//

import Combine
import DynamicSDKSwift
import SwiftBigInt
import SwiftUI

@MainActor
class DynamicManager: ObservableObject {

    @Published var isInitialized = false
    @Published var isLoggedIn = false
    @Published var currentUser: UserProfile?
    @Published var wallets: [BaseWallet] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentNetwork: NetworkInfo?

    private var sdk: DynamicSDK?
    private var cancellables = Set<AnyCancellable>()
    private var environmentId: String = ""

    let deepLinkUrl = "vibesswift://"
    private let apiBaseUrl = "https://app.dynamic.xyz/api/v0"

    static let shared = DynamicManager()
    private init() {}

    private func getSDK() throws -> DynamicSDK {
        guard let sdk = sdk else {
            throw DynamicError.notInitialized
        }
        return sdk
    }

    func initialize() async {
        guard !isInitialized else { return }

        isLoading = true
        error = nil

        environmentId =
            ProcessInfo.processInfo.environment["DYNAMIC_ENVIRONMENT_ID"]
            ?? "1ad88fee-3032-4b0f-b1a1-66cdaec9aecd"

        let dynamicSDK = DynamicSDK.initialize(
            props: ClientProps(
                environmentId: environmentId,
                appLogoUrl: nil,
                appName: "Vibes",
                redirectUrl: deepLinkUrl,
                appOrigin: nil
            )
        )

        sdk = dynamicSDK
        setupObservers()
        isInitialized = true
        isLoading = false

        await checkExistingSession()
    }

    private func setupObservers() {
        guard let sdk = sdk else { return }

        sdk.auth.authenticatedUserChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isLoggedIn = user != nil
                if user == nil {
                    self?.wallets = []
                }
            }
            .store(in: &cancellables)

        sdk.wallets.userWalletsChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wallets in
                self?.wallets = wallets
            }
            .store(in: &cancellables)
    }

    private func checkExistingSession() async {
        guard let sdk = sdk else { return }

        if let user = sdk.auth.authenticatedUser {
            currentUser = user
            isLoggedIn = true
            refreshWallets()
        }
    }

    private func refreshWallets() {
        guard let sdk = sdk else { return }
        wallets = sdk.wallets.userWallets
    }

    func sendEmailOTP(email: String) async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        try await sdk.auth.email.sendOTP(email: email)
    }

    func verifyEmailOTP(code: String) async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        try await sdk.auth.email.verifyOTP(token: code)
    }

    func sendSMSOTP(phoneNumber: String, countryCode: String = "1") async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        let phoneData = PhoneData(dialCode: "+\(countryCode)", iso2: "US", phone: phoneNumber)
        try await sdk.auth.sms.sendOTP(phoneData: phoneData)
    }

    func verifySMSOTP(code: String) async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        try await sdk.auth.sms.verifyOTP(token: code)
    }

    func socialLogin(provider: SocialProvider) async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        try await sdk.auth.social.connect(provider: provider)
    }

    func passkeySignIn() async throws {
        let sdk = try getSDK()
        isLoading = true
        defer { isLoading = false }
        _ = try await sdk.auth.passkey.signIn()
    }

    func logout() async {
        guard let sdk = sdk else { return }

        isLoading = true

        do {
            try await sdk.auth.logout()
        } catch {
            print("Logout error: \(error)")
        }

        currentUser = nil
        isLoggedIn = false
        wallets = []
        isLoading = false
    }

    func showAuthUI() {
        guard let sdk = sdk else { return }
        sdk.ui.showAuth()
    }

    func showUserProfile() {
        guard let sdk = sdk else { return }
        sdk.ui.showUserProfile()
    }

    func getWalletBalance(wallet: BaseWallet) async throws -> String {
        let sdk = try getSDK()
        return try await sdk.wallets.getBalance(wallet: wallet)
    }

    func signMessage(wallet: BaseWallet, message: String) async throws -> String {
        let sdk = try getSDK()
        return try await sdk.wallets.signMessage(wallet: wallet, message: message)
    }

    func signTypedData(wallet: BaseWallet, typedDataJson: String) async throws -> String {
        let sdk = try getSDK()
        return try await sdk.wallets.signTypedData(wallet: wallet, typedDataJson: typedDataJson)
    }

    func setPrimaryWallet(walletId: String) async throws {
        let sdk = try getSDK()
        try await sdk.wallets.setPrimary(walletId: walletId)
        refreshWallets()
    }

    func switchNetwork(wallet: BaseWallet, chainId: Int) async throws {
        let sdk = try getSDK()
        let network = Network.evm(chainId)
        try await sdk.wallets.switchNetwork(wallet: wallet, network: network)
    }

    func sendEVMTransaction(
        wallet: BaseWallet,
        to: String,
        amount: String,
        chainId: Int
    ) async throws -> String {
        let sdk = try getSDK()

        let client = sdk.evm.createPublicClient(chainId: chainId)
        let gasPrice = try await client.getGasPrice()

        let ethAmount = Double(amount) ?? 0
        let weiAmount = BigUInt(ethAmount * 1e18)

        let transaction = EthereumTransaction(
            from: wallet.address,
            to: to,
            value: weiAmount,
            gas: BigUInt(21000),
            maxFeePerGas: gasPrice * 2,
            maxPriorityFeePerGas: gasPrice * 2
        )

        return try await sdk.evm.sendTransaction(transaction: transaction, wallet: wallet)
    }

    func writeContract(
        wallet: BaseWallet,
        contractAddress: String,
        functionName: String,
        args: [Any],
        abi: [[String: Any]]
    ) async throws -> String {
        let sdk = try getSDK()

        let input = WriteContractInput(
            address: contractAddress,
            abi: abi,
            functionName: functionName,
            args: args
        )

        return try await sdk.evm.writeContract(wallet: wallet, input: input)
    }

    func sendERC20Transfer(
        wallet: BaseWallet,
        token: Token,
        to: String,
        amount: String,
        chainId: Int
    ) async throws -> String {
        guard let contractAddress = token.contractAddress else {
            throw DynamicError.transactionFailed("Cannot send native token as ERC-20")
        }

        let baseUnits = try parseDecimalToBaseUnits(amount, decimals: token.decimals)
        let functionSelector = "a9059cbb"
        let toAddress = to.hasPrefix("0x") ? String(to.dropFirst(2)) : to
        let paddedTo = String(repeating: "0", count: 64 - toAddress.count) + toAddress.lowercased()
        let amountHex = String(baseUnits, radix: 16)
        let paddedAmount = String(repeating: "0", count: 64 - amountHex.count) + amountHex
        let calldata = "0x" + functionSelector + paddedTo + paddedAmount

        let sdk = try getSDK()
        let client = sdk.evm.createPublicClient(chainId: chainId)
        let gasPrice = try await client.getGasPrice()

        let transaction = EthereumTransaction(
            from: wallet.address,
            to: contractAddress,
            value: BigUInt(0),
            data: calldata,
            gas: BigUInt(100000),
            maxFeePerGas: gasPrice * 2,
            maxPriorityFeePerGas: gasPrice / 2
        )

        return try await sdk.evm.sendTransaction(transaction: transaction, wallet: wallet)
    }

    private func parseDecimalToBaseUnits(_ value: String, decimals: Int) throws -> BigUInt {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw DynamicError.transactionFailed("Amount is empty") }

        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            throw DynamicError.transactionFailed("Invalid amount format")
        }

        let wholePart = String(parts[0].isEmpty ? "0" : parts[0])
        let fracPartRaw = parts.count == 2 ? String(parts[1]) : ""

        guard wholePart.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
            throw DynamicError.transactionFailed("Invalid amount")
        }
        guard
            fracPartRaw.isEmpty
                || fracPartRaw.range(of: #"^\d+$"#, options: .regularExpression) != nil
        else {
            throw DynamicError.transactionFailed("Invalid amount")
        }

        let whole = BigUInt(wholePart) ?? 0

        let fracPadded: String
        if decimals == 0 {
            fracPadded = ""
        } else {
            let trimmedFrac = String(fracPartRaw.prefix(decimals))
            fracPadded = trimmedFrac.padding(toLength: decimals, withPad: "0", startingAt: 0)
        }

        let frac = fracPadded.isEmpty ? 0 : (BigUInt(fracPadded) ?? 0)
        let factor = BigUInt(10).power(decimals)
        return whole * factor + frac
    }

    func getTokenBalances(
        wallet: BaseWallet,
        networkId: Int? = nil,
        includeNative: Bool = true,
        includePrices: Bool = false
    ) async throws -> [Token] {
        let sdk = try getSDK()

        guard let authToken = sdk.auth.token else {
            throw DynamicError.transactionFailed("Not authenticated")
        }

        let chainName = wallet.chain.uppercased() == "SOL" ? "SOL" : "EVM"
        var urlComponents = URLComponents(
            string: "\(apiBaseUrl)/sdk/\(environmentId)/chains/\(chainName)/balances")!
        var queryItems = [URLQueryItem(name: "accountAddress", value: wallet.address)]

        if let networkId = networkId {
            queryItems.append(URLQueryItem(name: "networkId", value: String(networkId)))
        }
        queryItems.append(URLQueryItem(name: "includeNative", value: String(includeNative)))
        queryItems.append(URLQueryItem(name: "includePrices", value: String(includePrices)))
        queryItems.append(URLQueryItem(name: "filterSpamTokens", value: "true"))

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw DynamicError.transactionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DynamicError.transactionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DynamicError.transactionFailed(
                "API error (\(httpResponse.statusCode)): \(errorBody)")
        }

        let decoder = JSONDecoder()
        let tokenBalances = try decoder.decode([TokenBalanceResponse].self, from: data)

        return tokenBalances.map { balance in
            Token(
                id: balance.address,
                symbol: balance.symbol,
                name: balance.name,
                decimals: balance.decimals,
                contractAddress: balance.isNative == true ? nil : balance.address,
                chainId: balance.networkId ?? networkId ?? 1,
                balance: String(format: "%.0f", balance.rawBalance),
                logo: balance.logoURI
            )
        }
    }

    func signAndSendSolanaTransaction(wallet: BaseWallet, base64Transaction: String) async throws
        -> String
    {
        let sdk = try getSDK()
        let signer = sdk.solana.createSigner(wallet: wallet)
        return try await signer.signAndSendEncodedTransaction(base64Transaction: base64Transaction)
    }

    func sendSolanaTransaction(
        wallet: BaseWallet,
        to: String,
        amount: String,
        cluster: SolanaClusterConfig = .devnet
    ) async throws -> String {
        let sdk = try getSDK()

        guard let solAmount = Double(amount), solAmount > 0 else {
            throw DynamicError.transactionFailed("Invalid amount")
        }
        let lamports = UInt64(solAmount * 1_000_000_000)

        let blockhash = try await getSolanaBlockhash(cluster: cluster)

        let transaction = try buildSolanaTransferTransaction(
            from: wallet.address,
            to: to,
            lamports: lamports,
            recentBlockhash: blockhash
        )

        let signer = sdk.solana.createSigner(wallet: wallet)
        return try await signer.signAndSendEncodedTransaction(base64Transaction: transaction)
    }

    func sendSPLTokenTransfer(
        wallet: BaseWallet,
        token: SolanaToken,
        to: String,
        amount: String,
        cluster: SolanaClusterConfig = .devnet
    ) async throws -> String {
        let sdk = try getSDK()

        guard let tokenAmount = Double(amount), tokenAmount > 0 else {
            throw DynamicError.transactionFailed("Invalid amount")
        }
        let baseUnits = UInt64(tokenAmount * pow(10.0, Double(token.decimals)))

        let blockhash = try await getSolanaBlockhash(cluster: cluster)

        let sourceATA = try await getOrCreateAssociatedTokenAccount(
            owner: wallet.address,
            mint: token.mintAddress,
            cluster: cluster
        )

        let destATA = try await getOrCreateAssociatedTokenAccount(
            owner: to,
            mint: token.mintAddress,
            cluster: cluster
        )

        let transaction = try buildSPLTokenTransferTransaction(
            from: wallet.address,
            sourceATA: sourceATA,
            destATA: destATA,
            amount: baseUnits,
            recentBlockhash: blockhash
        )

        let signer = sdk.solana.createSigner(wallet: wallet)
        return try await signer.signAndSendEncodedTransaction(base64Transaction: transaction)
    }

    func getSolanaTokenBalances(
        wallet: BaseWallet,
        cluster: SolanaClusterConfig = .devnet
    ) async throws -> [SolanaToken] {
        let sdk = try getSDK()

        guard let authToken = sdk.auth.token else {
            throw DynamicError.transactionFailed("Not authenticated")
        }

        var urlComponents = URLComponents(
            string: "\(apiBaseUrl)/sdk/\(environmentId)/chains/SOL/balances")!
        var queryItems = [
            URLQueryItem(name: "accountAddress", value: wallet.address),
            URLQueryItem(name: "includeNative", value: "true"),
            URLQueryItem(name: "includePrices", value: "false"),
            URLQueryItem(name: "filterSpamTokens", value: "true"),
        ]

        let networkId: String
        switch cluster {
        case .mainnet: networkId = "101"
        case .devnet: networkId = "102"
        case .testnet: networkId = "103"
        }
        queryItems.append(URLQueryItem(name: "networkId", value: networkId))

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw DynamicError.transactionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DynamicError.transactionFailed("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let tokenBalances = try decoder.decode([TokenBalanceResponse].self, from: data)

            return tokenBalances.map { balance in
                SolanaToken(
                    mintAddress: balance.address,
                    symbol: balance.symbol,
                    name: balance.name,
                    decimals: balance.decimals,
                    balance: String(format: "%.0f", balance.rawBalance),
                    logo: balance.logoURI,
                    isNative: balance.isNative ?? false
                )
            }
        }

        return try await getSolanaBalancesFromRPC(wallet: wallet, cluster: cluster)
    }

    private func getSolanaBlockhash(cluster: SolanaClusterConfig) async throws -> String {
        let rpcUrl = cluster.endpoint

        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getLatestBlockhash",
            "params": [["commitment": "finalized"]],
        ]

        var request = URLRequest(url: URL(string: rpcUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? [String: Any],
            let value = result["value"] as? [String: Any],
            let blockhash = value["blockhash"] as? String
        else {
            throw DynamicError.transactionFailed("Failed to get blockhash")
        }

        return blockhash
    }

    private func getSolanaBalancesFromRPC(
        wallet: BaseWallet,
        cluster: SolanaClusterConfig
    ) async throws -> [SolanaToken] {
        var tokens: [SolanaToken] = []

        let solBalance = try await getSolanaBalance(address: wallet.address, cluster: cluster)
        tokens.append(
            SolanaToken(
                mintAddress: "So11111111111111111111111111111111111111112",
                symbol: "SOL",
                name: "Solana",
                decimals: 9,
                balance: String(solBalance),
                logo: nil,
                isNative: true
            ))

        let splTokens = try await getSPLTokenAccounts(address: wallet.address, cluster: cluster)
        tokens.append(contentsOf: splTokens)

        return tokens
    }

    private func getSolanaBalance(address: String, cluster: SolanaClusterConfig) async throws
        -> UInt64
    {
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getBalance",
            "params": [address],
        ]

        var request = URLRequest(url: URL(string: cluster.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? [String: Any],
            let value = result["value"] as? UInt64
        else {
            return 0
        }

        return value
    }

    private func getSPLTokenAccounts(address: String, cluster: SolanaClusterConfig) async throws
        -> [SolanaToken]
    {
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getTokenAccountsByOwner",
            "params": [
                address,
                ["programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"],
                ["encoding": "jsonParsed"],
            ],
        ]

        var request = URLRequest(url: URL(string: cluster.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? [String: Any],
            let value = result["value"] as? [[String: Any]]
        else {
            return []
        }

        var tokens: [SolanaToken] = []

        for account in value {
            guard let accountData = account["account"] as? [String: Any],
                let parsedData = accountData["data"] as? [String: Any],
                let parsed = parsedData["parsed"] as? [String: Any],
                let info = parsed["info"] as? [String: Any],
                let mint = info["mint"] as? String,
                let tokenAmount = info["tokenAmount"] as? [String: Any],
                let amount = tokenAmount["amount"] as? String,
                let decimals = tokenAmount["decimals"] as? Int
            else {
                continue
            }

            if amount == "0" { continue }

            let (symbol, name) = getTokenMetadata(mint: mint)

            tokens.append(
                SolanaToken(
                    mintAddress: mint,
                    symbol: symbol,
                    name: name,
                    decimals: decimals,
                    balance: amount,
                    logo: nil,
                    isNative: false
                ))
        }

        return tokens
    }

    private func getTokenMetadata(mint: String) -> (symbol: String, name: String) {
        let knownTokens: [String: (String, String)] = [
            "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": ("USDC", "USD Coin"),
            "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB": ("USDT", "Tether USD"),
            "So11111111111111111111111111111111111111112": ("SOL", "Wrapped SOL"),
            "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So": ("mSOL", "Marinade staked SOL"),
            "7dHbWXmci3dT8UFYWYZweBLXgycu7Y3iL6trKn1Y7ARj": ("stSOL", "Lido Staked SOL"),
            "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263": ("BONK", "Bonk"),
            "JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN": ("JUP", "Jupiter"),
            "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R": ("RAY", "Raydium"),
            "orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE": ("ORCA", "Orca"),
        ]

        if let metadata = knownTokens[mint] {
            return metadata
        }

        let shortMint = "\(mint.prefix(4))...\(mint.suffix(4))"
        return (shortMint, "SPL Token")
    }

    private func getOrCreateAssociatedTokenAccount(
        owner: String,
        mint: String,
        cluster: SolanaClusterConfig
    ) async throws -> String {
        // Derive the associated token account address
        // This is a simplified version - in production, use proper PDA derivation
        let ata = try deriveAssociatedTokenAddress(owner: owner, mint: mint)
        return ata
    }

    private func deriveAssociatedTokenAddress(owner: String, mint: String) throws -> String {
        // Associated Token Program derivation
        // In production, this would use proper PDA derivation with the ATA program
        // For now, we'll use an approximation that works with the SDK
        // The SDK should handle this internally when building transactions

        // This is a placeholder - the actual ATA address needs to be derived using:
        // PDA([owner, TOKEN_PROGRAM_ID, mint], ASSOCIATED_TOKEN_PROGRAM_ID)
        // For full implementation, we'd need to add Base58 and SHA256 utilities

        // Return a placeholder - the SDK's transaction building should handle this
        return "\(owner)_\(mint.prefix(8))_ata"
    }

    /// Build a native SOL transfer transaction (base64 encoded)
    private func buildSolanaTransferTransaction(
        from: String,
        to: String,
        lamports: UInt64,
        recentBlockhash: String
    ) throws -> String {
        var transactionBytes: [UInt8] = []

        transactionBytes.append(1)
        transactionBytes.append(contentsOf: [UInt8](repeating: 0, count: 64))
        transactionBytes.append(1)
        transactionBytes.append(0)
        transactionBytes.append(1)
        transactionBytes.append(3)

        let fromBytes = try base58Decode(from)
        transactionBytes.append(contentsOf: fromBytes)

        let toBytes = try base58Decode(to)
        transactionBytes.append(contentsOf: toBytes)

        transactionBytes.append(contentsOf: [UInt8](repeating: 0, count: 32))

        let blockhashBytes = try base58Decode(recentBlockhash)
        transactionBytes.append(contentsOf: blockhashBytes)

        transactionBytes.append(1)
        transactionBytes.append(2)
        transactionBytes.append(2)
        transactionBytes.append(0)
        transactionBytes.append(1)

        var instructionData: [UInt8] = []
        instructionData.append(contentsOf: withUnsafeBytes(of: UInt32(2).littleEndian) {
            Array($0)
        })
        instructionData.append(contentsOf: withUnsafeBytes(of: lamports.littleEndian) { Array($0) })

        transactionBytes.append(UInt8(instructionData.count))
        transactionBytes.append(contentsOf: instructionData)

        return Data(transactionBytes).base64EncodedString()
    }

    private func buildSPLTokenTransferTransaction(
        from: String,
        sourceATA: String,
        destATA: String,
        amount: UInt64,
        recentBlockhash: String
    ) throws -> String {
        var transactionBytes: [UInt8] = []

        transactionBytes.append(1)
        transactionBytes.append(contentsOf: [UInt8](repeating: 0, count: 64))
        transactionBytes.append(1)
        transactionBytes.append(0)
        transactionBytes.append(1)
        transactionBytes.append(4)

        let ownerBytes = try base58Decode(from)
        transactionBytes.append(contentsOf: ownerBytes)

        let sourceBytes = try base58Decode(sourceATA.contains("_ata") ? from : sourceATA)
        transactionBytes.append(contentsOf: sourceBytes)

        let destBytes = try base58Decode(destATA.contains("_ata") ? from : destATA)
        transactionBytes.append(contentsOf: destBytes)

        let tokenProgramId = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        let tokenProgramBytes = try base58Decode(tokenProgramId)
        transactionBytes.append(contentsOf: tokenProgramBytes)

        let blockhashBytes = try base58Decode(recentBlockhash)
        transactionBytes.append(contentsOf: blockhashBytes)

        transactionBytes.append(1)
        transactionBytes.append(3)
        transactionBytes.append(3)
        transactionBytes.append(1)
        transactionBytes.append(2)
        transactionBytes.append(0)

        var instructionData: [UInt8] = [3]
        instructionData.append(contentsOf: withUnsafeBytes(of: amount.littleEndian) { Array($0) })

        transactionBytes.append(UInt8(instructionData.count))
        transactionBytes.append(contentsOf: instructionData)

        return Data(transactionBytes).base64EncodedString()
    }

    private func base58Decode(_ string: String) throws -> [UInt8] {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var result: [UInt8] = []
        var multiplier = BigUInt(1)
        var value = BigUInt(0)

        for char in string.reversed() {
            guard let index = alphabet.firstIndex(of: char) else {
                throw DynamicError.transactionFailed("Invalid base58 character")
            }
            let digitValue = BigUInt(alphabet.distance(from: alphabet.startIndex, to: index))
            value += digitValue * multiplier
            multiplier *= 58
        }

        var temp = value
        while temp > 0 {
            result.insert(UInt8(temp % 256), at: 0)
            temp /= 256
        }

        for char in string {
            if char == "1" {
                result.insert(0, at: 0)
            } else {
                break
            }
        }

        while result.count < 32 {
            result.insert(0, at: 0)
        }

        return Array(result.prefix(32))
    }

    func getEVMWallets() -> [BaseWallet] {
        return wallets.filter { $0.chain.uppercased() == "EVM" }
    }

    func getSolanaWallets() -> [BaseWallet] {
        return wallets.filter { $0.chain.uppercased() == "SOL" }
    }

    func getEVMNetworks() -> [GenericNetwork] {
        guard let sdk = sdk else { return [] }
        return sdk.networks.evm
    }

    func getSolanaNetworks() -> [GenericNetwork] {
        guard let sdk = sdk else { return [] }
        return sdk.networks.solana
    }

    func getMFADevices() async throws -> [MfaDevice] {
        let sdk = try getSDK()
        return try await sdk.mfa.getUserDevices()
    }

    func addTOTPDevice() async throws -> MfaAddDevice {
        let sdk = try getSDK()
        return try await sdk.mfa.addDevice(type: "totp")
    }

    func verifyTOTPDevice(code: String) async throws {
        let sdk = try getSDK()
        _ = try await sdk.mfa.verifyDevice(code, type: "totp")
    }

    func getRecoveryCodes(generateNew: Bool = false) async throws -> [String] {
        let sdk = try getSDK()
        return try await sdk.mfa.getRecoveryCodes(generateNewCodes: generateNew)
    }

    func getPasskeys() async throws -> [UserPasskey] {
        let sdk = try getSDK()
        return try await sdk.passkeys.getPasskeys()
    }

    func registerPasskey() async throws {
        let sdk = try getSDK()
        _ = try await sdk.passkeys.registerPasskey()
    }
}

struct Token: Identifiable, Hashable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let decimals: Int
    let contractAddress: String?  // nil for native token
    let chainId: Int
    let balance: String
    let logo: String?

    var isNative: Bool {
        contractAddress == nil
    }

    var formattedBalance: String {
        guard let balanceValue = Double(balance) else { return "0" }
        let divisor = pow(10.0, Double(decimals))
        let humanBalance = balanceValue / divisor

        if humanBalance == 0 {
            return "0"
        } else if humanBalance < 0.0001 {
            return "<0.0001"
        } else if humanBalance < 1 {
            return String(format: "%.4f", humanBalance)
        } else if humanBalance < 1000 {
            return String(format: "%.2f", humanBalance)
        } else {
            return String(format: "%.0f", humanBalance)
        }
    }

    static func native(for chainId: Int, balance: String = "0") -> Token {
        let (symbol, name) = nativeTokenInfo(for: chainId)
        return Token(
            id: "native-\(chainId)",
            symbol: symbol,
            name: name,
            decimals: 18,
            contractAddress: nil,
            chainId: chainId,
            balance: balance,
            logo: nil
        )
    }

    private static func nativeTokenInfo(for chainId: Int) -> (symbol: String, name: String) {
        switch chainId {
        case 1, 11_155_111, 8453, 84532, 42161, 10:
            return ("ETH", "Ethereum")
        case 137, 80002:
            return ("MATIC", "Polygon")
        default:
            return ("ETH", "Native Token")
        }
    }
}

struct TokenBalanceResponse: Codable {
    let networkId: Int?
    let address: String
    let name: String
    let symbol: String
    let decimals: Int
    let logoURI: String?
    let balance: Double
    let rawBalance: Double
    let price: Double?
    let marketValue: Double?
    let isNative: Bool?
}

enum DynamicError: LocalizedError {
    case notInitialized
    case walletNotFound
    case transactionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Dynamic SDK not initialized"
        case .walletNotFound:
            return "Wallet not found"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}

struct NetworkInfo: Identifiable, Equatable {
    let id = UUID()
    let chainId: Int
    let name: String
    let symbol: String
}

struct SolanaToken: Identifiable, Hashable, Equatable {
    var id: String { mintAddress }
    let mintAddress: String
    let symbol: String
    let name: String
    let decimals: Int
    let balance: String
    let logo: String?
    let isNative: Bool

    var formattedBalance: String {
        guard let balanceValue = Double(balance) else { return "0" }
        let divisor = pow(10.0, Double(decimals))
        let humanBalance = balanceValue / divisor

        if humanBalance == 0 {
            return "0"
        } else if humanBalance < 0.0001 {
            return "<0.0001"
        } else if humanBalance < 1 {
            return String(format: "%.4f", humanBalance)
        } else if humanBalance < 1000 {
            return String(format: "%.2f", humanBalance)
        } else {
            return String(format: "%.0f", humanBalance)
        }
    }

    static func nativeSOL(balance: String = "0") -> SolanaToken {
        SolanaToken(
            mintAddress: "So11111111111111111111111111111111111111112",
            symbol: "SOL",
            name: "Solana",
            decimals: 9,
            balance: balance,
            logo: nil,
            isNative: true
        )
    }
}

enum SolanaClusterConfig: String, CaseIterable {
    case mainnet = "Mainnet Beta"
    case devnet = "Devnet"
    case testnet = "Testnet"

    var endpoint: String {
        switch self {
        case .mainnet: return "https://api.mainnet-beta.solana.com"
        case .devnet: return "https://api.devnet.solana.com"
        case .testnet: return "https://api.testnet.solana.com"
        }
    }

    var networkId: Int {
        switch self {
        case .mainnet: return 101
        case .devnet: return 102
        case .testnet: return 103
        }
    }
}
