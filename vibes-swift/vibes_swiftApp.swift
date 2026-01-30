//
//  vibes_swiftApp.swift
//  vibes-swift
//

import SwiftUI
import DynamicSDKSwift

@main
struct vibes_swiftApp: App {

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in handleDeepLink(url) }
        }
    }

    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func handleDeepLink(_ url: URL) {
        print("Received deep link: \(url)")
    }
}
