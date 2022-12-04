//
//  AppDelegate.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

import Foundation
import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    
    func resetIcon() {
        self.updateIcon("-", inProgress: false)
    }
    
    func updateIcon(_ min: String, inProgress: Bool) {
        let iconSwiftUI = ZStack {
            Circle()
                .fill(inProgress ? Color.white.opacity(0.8) : Color.gray.opacity(0.4))
            
            Text(min)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(inProgress ? Color.black : Color.white).zIndex(1)
        }
            .frame(height: 18)
        let iconView = NSHostingView(rootView: iconSwiftUI)
        iconView.frame = NSRect(x: 0, y: 0, width: 42, height: 22)
        
        if let button = self.statusBarItem?.button {
            if (button.subviews.count != 0) {
                for subview in self.statusBarItem!.button!.subviews {
                    subview.removeFromSuperview()
                }
            }
            
            button.addSubview(iconView)
            button.frame = iconView.frame
            
            button.action = #selector(self.handleTrayIconClick(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    func activateApplication() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func handleTrayIconClick(sender: NSStatusItem) {
        activateApplication()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if self.statusBarItem!.button != nil {
            updateIcon("-", inProgress: false)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound])
    }
}
