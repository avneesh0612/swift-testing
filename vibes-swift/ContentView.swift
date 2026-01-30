//
//  ContentView.swift
//  vibes-swift
//
//  Main content view - handles authentication state and navigation
//

import SwiftUI
import DynamicSDKSwift

struct ContentView: View {
    @StateObject private var dynamicManager = DynamicManager.shared
    @State private var isInitializing = true
    
    var body: some View {
        Group {
            if isInitializing {
                InitializingView()
            } else if dynamicManager.isLoggedIn {
                DashboardView(dynamicManager: dynamicManager)
            } else {
                AuthenticationView(dynamicManager: dynamicManager)
            }
        }
        .task { await initializeSDK() }
    }

    private func initializeSDK() async {
        await dynamicManager.initialize()
        try? await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                isInitializing = false
            }
        }
    }
}

struct InitializingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                Image(systemName: "cube.transparent")
                    .font(.system(size: 40))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            VStack(spacing: 8) {
                Text("Vibes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Initializing Web3...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    ContentView()
}
