//
//  ccbiliApp.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//

import SwiftUI

@main
struct ccbiliApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
    }
}
