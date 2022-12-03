//
//  ContentView.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

import SwiftUI
import UserNotifications

struct LongLine: View {
    var color: Color = Color.gray
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: 18, alignment: .center)
    }
}

struct ShortLine: View {
    var color: Color = Color.gray
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: 14, alignment: .center)
    }
}

struct Progress: View {
    var value: Double
    var total: Double
    
    var body: some View {
        ZStack {
            ProgressView(value: value, total: total).zIndex(1)
            HStack {
                ShortLine()
                Spacer()
                ForEach((1...15), id: \.self) {_ in
                    ShortLine(color: Color.gray.opacity(0.5))
                    Spacer()
                }
                ShortLine()
            }
            HStack {
                LongLine()
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine()
            }
        }
    }
}

struct Progress_Previews: PreviewProvider {
    static var previews: some View {
        Progress(value: 5, total: 10).padding().frame(width: 200)
    }
}

struct ContentView: View {
    let appDelegate: AppDelegate
    let workSessionSeconds: Double = 25 * 60 // 25 min
    let workDaySeconds: Double = 400 * 60 // 400 min
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var counter: Double = 24 * 60 + 55
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
//        content.subtitle = "5 min"
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
                            NSApp.activate(ignoringOtherApps: true)
                        } else if (remainder == 0) {
                            showNotification()
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                    
                    
                }
            Progress(value: counter, total: workDaySeconds)
            
            HStack {
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
            }
        }
        .padding()
    }
}

