//
//  NostrEvent.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 05/02/2023.
//

import Foundation
import Crypto
import NostrKit
import secp256k1

private extension Collection {
    func unfoldSubSequences(ofMaxLength maxSequenceLength: Int) -> UnfoldSequence<SubSequence, Index> {
        sequence(state: startIndex) { current in
            guard current < endIndex else { return nil }
            
            let upperBound = index(current, offsetBy: maxSequenceLength, limitedBy: endIndex) ?? endIndex
            defer { current = upperBound }
            
            return self[current..<upperBound]
        }
    }
}

extension Data {
    enum DecodingError: Error {
        case oddNumberOfCharacters
        case invalidHexCharacters([Character])
    }
    
    func hex() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
    
    init(hex: String) throws {
        guard hex.count.isMultiple(of: 2) else { throw DecodingError.oddNumberOfCharacters }
        
        self = .init(capacity: hex.utf8.count / 2)

        for pair in hex.unfoldSubSequences(ofMaxLength: 2) {
            guard let byte = UInt8(pair, radix: 16) else {
                let invalidCharacters = Array(pair.filter({ !$0.isHexDigit }))
                throw DecodingError.invalidHexCharacters(invalidCharacters)
            }
            
            append(byte)
        }
    }
}


struct KeyPair {
    typealias PrivateKey = secp256k1.Signing.PrivateKey
    typealias PublicKey = secp256k1.Signing.PublicKey
    
    private let privateKey: PrivateKey
    
    var schnorrSigner: secp256k1.Signing.SchnorrSigner {
        return privateKey.schnorr
    }
    
    var schnorrValidator: secp256k1.Signing.SchnorrValidator {
        return privateKey.publicKey.schnorr
    }
    
    public var publicKey: String {
        return Data(privateKey.publicKey.xonly.bytes).hex()
    }
    
    public init() throws {
        privateKey = try PrivateKey()
    }
    
    public init(privateKey: String) throws {
        self = try .init(privateKey: try Data(hex: privateKey))
    }
    
    public init(privateKey: Data) throws {
        self.privateKey = try PrivateKey(rawRepresentation: privateKey)
    }
}


private struct SerializableEvent: Encodable {
    let id = 0
    let publicKey: String
    let createdAt: Timestamp
    let kind: EventKind
    let tags: [EventTag]
    let content: String
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(id)
        try container.encode(publicKey)
        try container.encode(createdAt)
        try container.encode(kind)
        try container.encode(tags)
        try container.encode(content)
    }
}

public struct NostrEvent: Codable {
    public let id: EventId
    public let publicKey: String
    public let createdAt: Timestamp
    public let kind: EventKind
    public let tags: [EventTag]
    public let content: String
    public let signature: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case publicKey = "pubkey"
        case createdAt = "created_at"
        case kind
        case tags
        case content
        case signature = "sig"
    }
    
    init(keyPair: KeyPair, kind: EventKind = .textNote, tags: [EventTag] = [], content: String) throws {
        publicKey = keyPair.publicKey
        createdAt = Timestamp(date: Date())
        self.kind = kind
        self.tags = tags
        self.content = content
        
        let serializableEvent = SerializableEvent(
            publicKey: publicKey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let serializedEvent = try encoder.encode(serializableEvent)
            self.id = Data(SHA256.hash(data: serializedEvent)).hex()
        
            let sig = try keyPair.schnorrSigner.signature(for: serializedEvent)
        
            guard keyPair.schnorrValidator.isValidSignature(sig, for: serializedEvent) else {
                throw EventError.signingFailed
            }

            self.signature = sig.rawRepresentation.hex()
        } catch is EncodingError {
            throw EventError.encodingFailed
        } catch {
            throw EventError.signingFailed
        }
    }
}
