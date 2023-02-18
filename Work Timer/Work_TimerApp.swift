//
//  Work_TimerApp.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

import SwiftUI

@main
struct Work_TimerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView(appDelegate: appDelegate)
            #endif
            
            #if os(iOS)
            ContentView()
            #endif
        }
    }
}
