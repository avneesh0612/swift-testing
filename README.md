# Vibes - Web3 iOS App with Dynamic SDK

A fully-functional Web3 iOS application built with the [Dynamic Swift SDK](https://www.dynamic.xyz/docs/swift/introduction). This app demonstrates a completely custom/headless UI implementation without using Dynamic's built-in widgets.

## Features

### Authentication

- **Email OTP** - Sign in with email and one-time password
- **SMS OTP** - Sign in with phone number and SMS verification
- **Social Login** - Google, Apple, Twitter, Discord, GitHub, Farcaster

### Wallet Management

- **EVM Wallets** - Ethereum, Polygon, Base, Arbitrum, Optimism
- **Solana Wallets** - Mainnet, Devnet, Testnet
- **Multi-chain Support** - Automatic wallet creation for enabled chains

### Transactions

- **Send ETH/Tokens** - Send transactions on EVM networks
- **Send SOL** - Send transactions on Solana
- **Message Signing** - Sign arbitrary messages
- **EIP-712 Typed Data** - Sign structured typed data

### Network Switching

- **Multiple Networks** - Switch between mainnet and testnets
- **Custom RPC** - Configure custom network endpoints

### Security

- **MPC Wallets** - Non-custodial embedded wallets
- **Export Keys** - Export private keys when needed
- **Recovery Options** - Email and social recovery

## Setup Instructions

### Prerequisites

- **iOS 13.0+**
- **Swift 5.9+**
- **Xcode 15.0+**
- **Dynamic Account** - Get your environment ID from [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/overview)

### 1. Add Swift Package Dependency

In Xcode:

1. Go to **File → Add Package Dependencies**
2. Enter the package URL: `https://github.com/dynamic-labs/swift-sdk-and-sample-app`
3. Select the `DynamicSDKSwift` package product
4. Add it to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dynamic-labs/swift-sdk-and-sample-app", from: "1.0.0")
]
```

### 2. Configure Environment Variables

In Xcode:

1. Go to **Product → Scheme → Edit Scheme**
2. Select **"Run"** from the left sidebar
3. Go to the **"Arguments"** tab
4. Under **"Environment Variables"**, add:

```
DYNAMIC_BASE_URL = https://app.dynamicauth.com/api/v0
DYNAMIC_RELAY_HOST = relay.dynamicauth.com
DYNAMIC_ENVIRONMENT_ID = <<your_environment_id>>
```

Replace `<<your_environment_id>>` with your environment ID from the Dynamic dashboard.

### 3. Configure URL Scheme

The `Info.plist` is already configured with the URL scheme `vibesswift://` for social authentication callbacks.

If you want to use a different scheme:

1. Update `Info.plist` with your custom scheme
2. Update the `deepLinkUrl` in `DynamicManager.swift`
3. Whitelist your deep link URL in the [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/security)

### 4. Enable Features in Dynamic Dashboard

1. Go to your [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/overview)
2. Enable authentication methods:
   - Email OTP
   - SMS OTP
   - Social providers (Apple, Google, etc.)
3. Enable embedded wallets:
   - EVM (Ethereum)
   - Solana (optional)
4. Enable networks:
   - Ethereum Mainnet/Sepolia
   - Polygon
   - Base
   - etc.

### 5. Build and Run

```bash
# Open in Xcode
open vibes-swift.xcodeproj

# Or build from command line
xcodebuild -scheme vibes-swift -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Project Structure

```
vibes-swift/
├── vibes_swiftApp.swift          # App entry point
├── ContentView.swift              # Main navigation controller
├── Info.plist                     # App configuration with URL schemes
├── Managers/
│   └── DynamicManager.swift       # Dynamic SDK wrapper and state management
├── Views/
│   ├── Authentication/
│   │   └── AuthenticationView.swift   # Email, SMS, Social auth
│   ├── Wallet/
│   │   └── WalletView.swift           # EVM and Solana wallets
│   ├── Transactions/
│   │   ├── SendTransactionView.swift  # Send ETH transactions
│   │   ├── SignMessageView.swift      # Sign messages and typed data
│   │   └── SolanaViews.swift          # Solana transactions and signing
│   └── Dashboard/
│       └── DashboardView.swift        # Main dashboard, activity, profile
└── Assets.xcassets/               # App icons and images
```

## Key Implementation Details

### Headless/Custom UI

This app uses Dynamic SDK's programmatic APIs instead of the built-in UI components:

```swift
// Instead of: sdk.ui.showAuth()
// We use programmatic methods:

// Email OTP
let verification = try await sendEmailOtp(client: client, email: email)
let user = try await verifyOtp(otpVerification: verification, verificationToken: code)

// Social Login
let user = try await socialLogin(client: client, with: .google, deepLinkUrl: deepLinkUrl)

// Transactions
let txHash = try await wallet.sendTransaction(transaction)

// Signing
let signature = try await wallet.signMessage(message: message)
```

### State Management

The app uses `DynamicSessionState` with Combine for reactive state management:

```swift
@StateObject private var dynamicManager = DynamicManager.shared

// Session state automatically updates UI
sessionState.$isLoggedIn
    .receive(on: DispatchQueue.main)
    .sink { loggedIn in
        // Update UI
    }
```

### Network Switching

```swift
// Get available networks
let networks = dynamicManager.getAvailableNetworks()

// Switch network
try await dynamicManager.switchNetwork(wallet: wallet, to: chainId)
```

## Testing

For testing, we recommend:

1. Use **Sepolia** or **Base Sepolia** testnets for EVM
2. Use **Devnet** for Solana
3. Get testnet tokens from faucets:
   - [Sepolia Faucet](https://sepoliafaucet.com/)
   - [Solana Devnet Faucet](https://faucet.solana.com/)

## Resources

- [Dynamic Swift SDK Documentation](https://www.dynamic.xyz/docs/swift/introduction)
- [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/overview)
- [Dynamic Swift SDK GitHub](https://github.com/dynamic-labs/swift-sdk-and-sample-app)
- [Dynamic Support (Slack)](https://www.dynamic.xyz/slack)

## License

MIT License - See LICENSE file for details.
