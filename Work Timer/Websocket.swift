//
//  Websocket.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 04/02/2023.
//

import Foundation
import NostrKit
import Network
import AppKit

enum ConnectionStatus {
    case Success
    case Error
}

class Websocket: ObservableObject {
    var instance: URLSessionWebSocketTask
    var networkMonitor: NWPathMonitor
    @Published var status: ConnectionStatus
    var onEvent: (_ event: Event) -> Void = { _ in }
    var connectCallback: () -> Void = {}
    
    init(
        instance: URLSessionWebSocketTask = Websocket.createWebsocketConnection(),
        networkMonitor: NWPathMonitor = NWPathMonitor(),
        status: ConnectionStatus = ConnectionStatus.Error
    ) {
        self.instance = instance
        self.networkMonitor = networkMonitor
        self.status = status
        
        networkMonitor.start(queue: DispatchQueue.main)
        networkMonitor.pathUpdateHandler = { path in
            self.status = path.status == .satisfied ? .Success : .Error
        }
        
        fileNotifications()
    }
    
    func setStatus(status: ConnectionStatus) {
        self.status = status
    }
    
    func sendMessage(message: NostrMessage) {
        do {
            if (self.instance.state != .running) {
                self.reconnect()
            }
            
            self.instance.send(.string(try message.string())) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error: \(error)")
                        self.status = .Error
                    }
                }
            }
        } catch let error {
            status = .Error
            print(error)
        }
    }
    
    func connect(onEvent: @escaping (_ event: Event) -> Void, callback: @escaping () -> Void) {
        self.onEvent = onEvent
        self.connectCallback = callback
        func listen() {
            self.instance.receive { result in
                switch result {
                case .success(let message):
                    DispatchQueue.main.async {
                        self.status = .Success
                        switch message {
                        case .string(let text):
                            do {
                                if (text.contains("\"EVENT\"")) {
                                    let message = try RelayMessage(text: text)
                                    if case .event(_, let event) = message {
                                        print(event)
                                        self.onEvent(event)
                                    }
                                }
                            } catch let error {
                                print(error)
                            }
                            
                        default:
                            self.status = .Error
                            print("Error: Received unknown message type")
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.status = .Error
                        print("Error: \(error)")                        
                    }
                }
                
                listen()
            }
        }
        
        listen()
        self.instance.resume()
        callback()
    }
    
    func reconnect() {
        self.instance = Websocket.createWebsocketConnection()
        self.connect(onEvent: self.onEvent, callback: self.connectCallback)
    }
    
    static func createWebsocketConnection() -> URLSessionWebSocketTask {
//        return URLSession(configuration: .default).webSocketTask(with: URL(string: "wss://nostr-pub.wellorder.net")!)
        return URLSession(configuration: .default).webSocketTask(with: URL(string: "ws://localhost:8080")!)
    }
    
    // sleep events
    
    @objc func onWakeNote(note: NSNotification) {
        self.reconnect()
    }

//    @objc func onSleepNote(note: NSNotification) {
//        print("sleep!")
//    }

    func fileNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWakeNote(note:)),
            name: NSWorkspace.didWakeNotification, object: nil)

//        NSWorkspace.shared.notificationCenter.addObserver(
//            self, selector: #selector(onSleepNote(note:)),
//            name: NSWorkspace.willSleepNotification, object: nil)
    }
}
