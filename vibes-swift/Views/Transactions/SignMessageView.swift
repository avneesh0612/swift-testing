//
//  SignMessageView.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift

struct SignMessageView: View {
    @ObservedObject var dynamicManager: DynamicManager
    let wallet: BaseWallet
    
    @State private var selectedSignType: SignType = .message
    @State private var message = ""
    @State private var typedData = ""
    @State private var signature: String?
    @State private var isLoading = false
    @State private var error: String?
    
    enum SignType: String, CaseIterable {
        case message = "Message"
        case typedData = "Typed Data (EIP-712)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signing Wallet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "wallet.pass.fill")
                            .foregroundColor(.purple)
                        Text(formatAddress(wallet.address))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                Picker("Sign Type", selection: $selectedSignType) {
                    ForEach(SignType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedSignType {
                case .message:
                    MessageInputView(message: $message)
                case .typedData:
                    TypedDataInputView(typedData: $typedData)
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
                        Button(action: { copySignature() }) {
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

                Button(action: sign) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "signature")
                            Text("Sign \(selectedSignType == .message ? "Message" : "Typed Data")")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSign ? Color.purple : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSign || isLoading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("About Signing")
                        .font(.headline)
                    Text(selectedSignType == .message ?
                        "Message signing allows you to prove ownership of your wallet address without making a transaction." :
                        "EIP-712 typed data signing provides structured, human-readable signing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Sign")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSign: Bool {
        switch selectedSignType {
        case .message:
            return !message.isEmpty
        case .typedData:
            return !typedData.isEmpty && isValidJSON(typedData)
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func copySignature() {
        if let sig = signature {
            UIPasteboard.general.string = sig
        }
    }

    private func sign() {
        isLoading = true
        error = nil
        signature = nil

        Task {
            do {
                let sig: String

                switch selectedSignType {
                case .message:
                    sig = try await dynamicManager.signMessage(wallet: wallet, message: message)
                case .typedData:
                    sig = try await dynamicManager.signTypedData(wallet: wallet, typedDataJson: typedData)
                }

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

struct MessageInputView: View {
    @Binding var message: String
    
    let exampleMessages = [
        "Hello, Web3!",
        "Sign in to Vibes App",
        "I agree to the terms of service",
        "Verify wallet ownership"
    ]
    
    var body: some View {
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
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(16)
                        }
                    }
                }
            }
        }
    }
}

struct TypedDataInputView: View {
    @Binding var typedData: String
    
    let exampleTypedData = """
{
  "types": {
    "EIP712Domain": [
      {"name": "name", "type": "string"},
      {"name": "version", "type": "string"},
      {"name": "chainId", "type": "uint256"}
    ],
    "Message": [
      {"name": "content", "type": "string"},
      {"name": "timestamp", "type": "uint256"}
    ]
  },
  "primaryType": "Message",
  "domain": {
    "name": "Vibes App",
    "version": "1",
    "chainId": 84532
  },
  "message": {
    "content": "Hello from Vibes!",
    "timestamp": 1706000000
  }
}
"""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Typed Data (EIP-712)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Load Example") {
                    typedData = exampleTypedData
                }
                .font(.caption)
                .foregroundColor(.purple)
            }

            TextEditor(text: $typedData)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            if !typedData.isEmpty {
                HStack {
                    if isValidJSON(typedData) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid JSON")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Invalid JSON")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
