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
import SwiftUI

enum ConnectionStatus {
    case Success
    case Error
}

let DEFAULT_RELAY = "wss://nostr-pub.wellorder.net"

class Websocket: ObservableObject {
    @AppStorage("relay") var relay = DEFAULT_RELAY
    var instance: URLSessionWebSocketTask = Websocket.createWebsocketConnection(url: DEFAULT_RELAY)
    var networkMonitor: NWPathMonitor = NWPathMonitor()
    @Published var status: ConnectionStatus = ConnectionStatus.Error
    var onEvent: (_ event: Event) -> Void = { _ in }
    var connectCallback: () -> Void = {}
    
    init() {
        setupNetworkMonitor()
    }
    
    func setupNetworkMonitor() {
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
        self.instance = Websocket.createWebsocketConnection(url: relay)
        self.onEvent = onEvent
        self.connectCallback = callback
        func listen() {
            func workItem() {
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
                                    print("LISTEN catch", error)
                                }
                                
                            default:
                                self.status = .Error
                                print("LISTEN default", "Error: Received unknown message type")
                            }
                        }
                    case .failure(let error):
                        if (self.status != .Error) {
                            self.status = .Error
                        }
                        
                        print("LISTEN Failure", "Error: \(error)")
                    }
                    
                    listen()
                }
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1 , execute: workItem)
        }
        
        listen()
        self.instance.resume()
        self.status = .Success
        
        callback()
    }
    
    func reconnect() {
        self.connect(onEvent: self.onEvent, callback: self.connectCallback)
    }
    
    static func createWebsocketConnection(url: String) -> URLSessionWebSocketTask {
        let url = (url.starts(with: "ws:") || url.starts(with: "wss:")) && url.count > 5 ? url : DEFAULT_RELAY
        return URLSession(configuration: .default)
            .webSocketTask(with: (URL(string: url) ?? URL(string: DEFAULT_RELAY))!)
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
