//
//  AppDelegate.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

#if os(macOS)

import Foundation
import SwiftUI
import UserNotifications
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    
    func resetIcon() {
        self.updateIcon("minus", inProgress: false)
    }
    
    func updateIcon(_ min: String, inProgress: Bool) {
        DispatchQueue.main.async {
            if let button = self.statusBarItem?.button {
                if (button.subviews.count != 0) {
                    for subview in self.statusBarItem!.button!.subviews {
                        subview.removeFromSuperview()
                    }
                }
                
                let iconSwiftUI = Image(systemName: "\(min).circle\(inProgress ? ".fill" : "")")
                    .resizable()
                    .frame(width: 17, height: 17)
                let iconView = NSHostingView(rootView: iconSwiftUI)
                iconView.frame = NSRect(x: 0, y: 0, width: 42, height: 22)
                
                button.addSubview(iconView)
                button.frame = iconView.frame
                
                button.action = #selector(self.handleTrayIconClick(sender:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }
    }
    
    func activateApplication() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(self)
        
        if let wnd = NSApp.windows.first {
            wnd.makeKeyAndOrderFront(self)
            wnd.setIsVisible(true)
        }
    }
    
    @objc func handleTrayIconClick(sender: NSStatusItem) {
        activateApplication()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if self.statusBarItem!.button != nil {
            resetIcon()
        }
    }
    
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound])
    }
}

#endif
