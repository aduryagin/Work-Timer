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

var disableUITask: DispatchWorkItem?

struct ContentView: View {
    let appDelegate: AppDelegate
    let workSessionSeconds: Double = 25 * 60 // 25 min
    let workDaySeconds: Double = 400 * 60 // 400 min
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let nostr = Nostr()
    @ObservedObject var websocket = Websocket()
    
    @AppStorage("clientId") private var clientId = String(bytes: try! secp256k1.Signing.PrivateKey().publicKey.rawRepresentation)
    @AppStorage("nostrPrivateKey") private var nostrPrivateKey = ""
    
    @State var isUIDisabled = false
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
            let message = NostrMessage.subscribe(subscription)
            websocket.sendMessage(message: message)
        } catch let error {
            websocket.setStatus(status: .Error)
            print(error)
        }
    }
    
    func sendSecondsToNostr() {
        do {
            let seconds = counter
            let event = try nostr.encryptedEvent(String("\(seconds) \(clientId)"), privateKey: nostrPrivateKey)
            
            if let event = event {
                let message = NostrMessage.event(event)
                websocket.sendMessage(message: message)
            }
        } catch let error {
            websocket.setStatus(status: .Error)
            print(error)
        }
    }
    
    func disableUI() {
        if (!isUIDisabled) {
            isUIDisabled = true            
        }
        
        disableUITask?.cancel()
        
        let task = DispatchWorkItem {
            DispatchQueue.main.async {
                isUIDisabled = false
            }
        }
        
        disableUITask = task
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0, execute: task)
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
                        }.disabled(isUIDisabled)
                        Button {
                            isNostrView.toggle()
                            pause()
                        } label: {
                            HStack(alignment: VerticalAlignment.center) {
                                Text("Nostr Sync settings")
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
                                sendSecondsToNostr()
                            }
                        } label: {
                            Text("Save")
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                } else if (isNostrView) {
                    VStack(alignment: .center) {
                        HStack {
                            TextField("Relay", text: $websocket.relay)
                                .onChange(of: websocket.relay, perform: { _ in
                                    websocket.reconnect()
                                })
                                .frame(width: 150)
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
                    sendSecondsToNostr()
                } label: {
                    Image(systemName: "chevron.left")
                }.disabled(counter == 0 || isSetCounterView || isNostrView || isUIDisabled)
                Button {
                    isTimerRunning = false
                    counter = 0
                    sendSecondsToNostr()
                    appDelegate.resetIcon()
                } label: {
                    Text("Reset")
                }.disabled(counter == 0 || isSetCounterView || isNostrView || isUIDisabled)
                Button {
                    isTimerRunning.toggle()
                } label: {
                    Text(isTimerRunning ? "Pause" : counter != 0 ? "Continue" : "Start")
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(isSetCounterView || isNostrView || isUIDisabled)
                Button {
                    let index = floor(counter / workSessionSeconds) + 1
                    counter = index * workSessionSeconds
                    sendSecondsToNostr()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(counter == workDaySeconds || isSetCounterView || isNostrView || isUIDisabled)
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
                    
                    if (pubkey != myPubkey) { return }
                    
                    let message = try nostr.decryptMessage(privateKey: nostrPrivateKey, content: event.content)
                    if (message == nil) { return }
                    
                    let content = message!.components(separatedBy: " ")
                    if (content.count != 2) { return }
                        
                    let messageSeconds = Double(content[0]) ?? 0.0
                    let messageClientId = content[1]
                    
                    if (clientId != messageClientId) {
                        disableUI()
                    }
                    
                    if (
                        isTimerRunning ||
                        (clientId == messageClientId && counter >= messageSeconds)
                    ) { return }
                    
                    counter = messageSeconds
                } catch let error {
                    print(error)
                }
            } callback: {
                subscribeToSecondsNostr()
            }
        }
    }
}
