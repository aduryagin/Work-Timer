//
//  NostrMessage.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 05/02/2023.
//

import Foundation
import NostrKit

public enum NostrMessage: Encodable {
    case event(NostrEvent)
    case subscribe(Subscription)
    case unsubscribe(SubscriptionId)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        switch self {
        case .event(let event):
            try container.encode("EVENT")
            try container.encode(event)
        case .subscribe(let subscription):
            try container.encode("REQ")
            try container.encode(subscription.id)
            try subscription.filters.forEach { try container.encode($0) }
        case .unsubscribe(let subscriptionId):
            try container.encode("CLOSE")
            try container.encode(subscriptionId)
        }
    }
    
    public func string() throws -> String {
        return String(data: try JSONEncoder().encode(self), encoding: .utf8)!
    }
}

