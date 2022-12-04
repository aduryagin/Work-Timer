//
//  ContentView.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    let appDelegate: AppDelegate
    let workSessionSeconds: Double = 25 * 60 // 25 min
    let workDaySeconds: Double = 400 * 60 // 400 min
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var counter: Double = 0
    @State var isTimerRunning = false
    
    func formatTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: TimeInterval(seconds))!
    }
    
    func formatMinutes(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let string = formatter.string(from: TimeInterval(seconds))!
        return string.hasPrefix("0") ? .init(string.dropFirst()) : string
    }
    
    func showNotification(message: String = "Time for a 5 min break") {
        let content = UNMutableNotificationContent()
        content.title = message
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request)
    }
    
    func updateTrayMins(inProgress: Bool) -> Double {
        let remainder = counter.truncatingRemainder(dividingBy: workSessionSeconds)
        appDelegate.updateIcon(formatMinutes(remainder), inProgress: inProgress)
        return remainder
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Text("\(String(formatTime(counter))) / \(String(formatTime(workDaySeconds)))")
                .font(.largeTitle)
                .onReceive(timer) { time in
                    if (isTimerRunning) {
                        counter += 1
                        let remainder = updateTrayMins(inProgress: true)
                        
                        if (counter == workDaySeconds) {
                            isTimerRunning = false
                            
                            showNotification(message: "Workday is over!")
                            appDelegate.activateApplication()
                        } else if (remainder == 0) {
                            var message = "Time for a 5 min break"
                            if (counter.truncatingRemainder(dividingBy: workSessionSeconds * 4) == 0) {
                                message = "Time for a 15 min break"
                            }
                            
                            showNotification(message: message)
                            appDelegate.activateApplication()
                        }
                    }
                    
                    
                }
            Progress(value: counter, total: workDaySeconds)
            
            HStack {
                Button {
                    let index = floor(counter / workSessionSeconds) - 1
                    counter = index * workSessionSeconds
                    let _ = updateTrayMins(inProgress: false)
                } label: {
                    Image(systemName: "chevron.left")
                }.disabled(counter == 0)
                Button {
                    isTimerRunning = false
                    counter = 0
                    appDelegate.resetIcon()
                } label: {
                    Text("Reset")
                }.disabled(counter == 0)
                Button {
                    isTimerRunning.toggle()
                    let _ = updateTrayMins(inProgress: isTimerRunning)
                } label: {
                    Text(isTimerRunning ? "Pause" : counter != 0 ? "Continue" : "Start")
                }
                Button {
                    let index = floor(counter / workSessionSeconds) + 1
                    counter = index * workSessionSeconds
                    let _ = updateTrayMins(inProgress: false)
                } label: {
                    Image(systemName: "chevron.right")
                }.disabled(counter == workDaySeconds)
            }
        }
        .padding()
    }
}

