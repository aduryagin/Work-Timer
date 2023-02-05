//
//  ContentView.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 03/12/2022.
//

import SwiftUI
import UserNotifications
import NostrKit
import secp256k1

struct ContentView: View {
    let appDelegate: AppDelegate
    let workSessionSeconds: Double = 25 * 60 // 25 min
    let workDaySeconds: Double = 400 * 60 // 400 min
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let nostr = Nostr()
    @ObservedObject var websocket = Websocket()
    
    @AppStorage("nostrPrivateKey") private var nostrPrivateKey = ""
    
    @State var isNostrView = false
    @State var isSetCounterView = false
    @State var newCounter: String = ""
    @State var isSessionView = false
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
    
    func getSessionSeconds() -> Double {
        return counter.truncatingRemainder(dividingBy: workSessionSeconds)
    }
    
    func updateTrayMins(inProgress: Bool) -> Double {
        let remainder = getSessionSeconds()
        appDelegate.updateIcon(formatMinutes(remainder), inProgress: inProgress)
        return remainder
    }
    
    func pause() {
        isTimerRunning = false
    }
    
    // Nostr
    
    func generateKeys() -> Void {
        let privateKey = try! secp256k1.Signing.PrivateKey()
        nostrPrivateKey = String(bytes: privateKey.rawRepresentation)
    }
    
    func subscribeToSecondsNostr() {
        do {
            // subscribe to my own private messages
            let keyPair = try KeyPair(privateKey: nostrPrivateKey)
            let subscription = Subscription(
                filters: [
                    .init(
                        authors: [keyPair.publicKey],
                        eventKinds: [.custom(4)],
                        limit: 1
                    )
                ]
            )
            let message = ClientMessage.subscribe(subscription)
            websocket.sendMessage(message: message)
        } catch let error {
            websocket.setStatus(status: .Error)
            print(error)
        }
    }
    
    func sendSecondsToNostr() {
        do {
            let seconds = counter
            let event = try nostr.encryptedEvent(String(seconds), privateKey: nostrPrivateKey)
            if let event = event {
                let message = ClientMessage.event(event)
                websocket.sendMessage(message: message)
            }
        } catch let error {
            websocket.setStatus(status: .Error)
            print(error)
        }
    }
    
    var body: some View {
        VStack(alignment: .center) {
            VStack(spacing: 5) {
                Text(!isSessionView ? "\(String(formatTime(counter))) / \(String(formatTime(workDaySeconds)))" : String(" \(formatMinutes(getSessionSeconds())) / 25"))
                    .font(.largeTitle)
                    .onTapGesture {
                        isSessionView.toggle()
                    }
                    .onReceive(timer) { time in
                        if (isTimerRunning) {
                            counter += 1
                            let remainder = getSessionSeconds()
                            
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
                if (!isSetCounterView && !isNostrView) {
                    HStack {
                        Button {
                            isSetCounterView.toggle()
                            pause()
                        } label: {
                            Text("Set seconds manually")
                        }
                        Button {
                            isNostrView.toggle()
                            pause()
                        } label: {
                            HStack(alignment: VerticalAlignment.center) {
                                Text("Sync via Nostr settings")
                                Circle()
                                    .fill(
                                        websocket.status == .Error ?
                                            Color.red :
                                            Color.green)
                                    .frame(height: 7)
                                    .padding(.top, 2)
                            }
                        }
                    }
                } else if (isSetCounterView) {
                    HStack {
                        TextField("Seconds", text: $newCounter).frame(width: 150)
                        Button {
                            let new = Double(newCounter) ?? counter
                            if (new < workDaySeconds && new >= 0) {
                                counter = new
                                isSetCounterView.toggle()
                            }
                        } label: {
                            Text("Save")
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                } else if (isNostrView) {
                    VStack(alignment: .center) {
                        HStack {
                            TextField("Key", text: $nostrPrivateKey).frame(width: 150)
                            Circle()
                                .fill(
                                    websocket.status == .Error ?
                                        Color.red :
                                        Color.green)
                                .frame(height: 7)
                                .padding(.top, 2)
                            Button {
                                generateKeys()
                                subscribeToSecondsNostr()
                            } label: {
                                Text("Regenerate")
                            }
                            Button {
                                isNostrView.toggle()
                            } label: {
                                Text("Cancel")
                            }
                        }
                        Text("Paste this key to another client. Keys must be equal.").font(.system(size: 11))
                    }
                }
            }
            
            Progress(value: counter, total: workDaySeconds)
            
            HStack {
                Button {
                    let index = floor(counter / workSessionSeconds) - 1
                    counter = index * workSessionSeconds
                } label: {
                    Image(systemName: "chevron.left")
                }.disabled(counter == 0 || isSetCounterView || isNostrView)
                Button {
                    isTimerRunning = false
                    counter = 0
                    appDelegate.resetIcon()
                } label: {
                    Text("Reset")
                }.disabled(counter == 0 || isSetCounterView || isNostrView)
                Button {
                    isTimerRunning.toggle()
                } label: {
                    Text(isTimerRunning ? "Pause" : counter != 0 ? "Continue" : "Start")
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(isSetCounterView || isNostrView)
                Button {
                    let index = floor(counter / workSessionSeconds) + 1
                    counter = index * workSessionSeconds
                } label: {
                    Image(systemName: "chevron.right")
                }.disabled(counter == workDaySeconds || isSetCounterView || isNostrView)
            }
        }
        .padding()
        .onChange(of: counter, perform: { counter in
            newCounter = String(counter)
            let _ = updateTrayMins(inProgress: isTimerRunning)
            
            // send private message about change
            if (isTimerRunning) {
                sendSecondsToNostr()
            }
        })
        .onChange(of: isTimerRunning, perform: { isRunning in
            let _ = updateTrayMins(inProgress: isRunning)
        })
        .onChange(of: nostrPrivateKey, perform: { privateKey in
            subscribeToSecondsNostr()
        })
        .onAppear {
            if (nostrPrivateKey == "") {
                generateKeys()
            }
            
            // ws
            websocket.connect() { event in
                do {
                    let pubkey = event.tags.first?.otherInformation[0]
                    let myPubkey = try KeyPair.init(privateKey: nostrPrivateKey).publicKey
                    
                    if (pubkey == myPubkey) {
                        let message = try nostr.decryptMessage(privateKey: nostrPrivateKey, content: event.content)
                        if (message != nil) {
                            counter = Double(message!) ?? 0.0
                        }
                    }                    
                } catch let error {
                    print(error)
                }
            } callback: {
                subscribeToSecondsNostr()
            }
        }
    }
}
