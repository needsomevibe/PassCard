//
//  PassCardApp.swift
//  PassCard
//
//  Created by needsomevibe on 08/01/26.
//

import SwiftUI

@main
struct PassCardApp: App {
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appAppearance.colorScheme)
        }
    }
}
