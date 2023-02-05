//
//  Nostr.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 04/02/2023.
//

import Foundation
import NostrKit
import secp256k1
import secp256k1_implementation
import CommonCrypto
import CryptoKit

class Nostr {
    func aes_operation(operation: CCOperation, data: [UInt8], iv: [UInt8], shared_sec: [UInt8]) -> Data? {
        let data_len = data.count
        let bsize = kCCBlockSizeAES128
        let len = Int(data_len) + bsize
        var decrypted_data = [UInt8](repeating: 0, count: len)

        let key_length = size_t(kCCKeySizeAES256)
        if shared_sec.count != key_length {
            assert(false, "unexpected shared_sec len: \(shared_sec.count) != 32")
            return nil
        }

        let algorithm: CCAlgorithm = UInt32(kCCAlgorithmAES128)
        let options:   CCOptions   = UInt32(kCCOptionPKCS7Padding)

        var num_bytes_decrypted :size_t = 0

        let status = CCCrypt(operation,  /*op:*/
                             algorithm,  /*alg:*/
                             options,    /*options:*/
                             shared_sec, /*key:*/
                             key_length, /*keyLength:*/
                             iv,         /*iv:*/
                             data,       /*dataIn:*/
                             data_len, /*dataInLength:*/
                             &decrypted_data,/*dataOut:*/
                             len,/*dataOutAvailable:*/
                             &num_bytes_decrypted/*dataOutMoved:*/
        )

        if UInt32(status) != UInt32(kCCSuccess) {
            return nil
        }

        return Data(bytes: decrypted_data, count: num_bytes_decrypted)

    }
    
    func aes_encrypt(data: [UInt8], iv: [UInt8], shared_sec: [UInt8]) -> Data? {
        return aes_operation(operation: CCOperation(kCCEncrypt), data: data, iv: iv, shared_sec: shared_sec)
    }
    
    func random_bytes(count: Int) -> Data {
        var bytes = [Int8](repeating: 0, count: count)
        guard
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess
        else {
            fatalError("can't copy secure random data")
        }
        return Data(bytes: bytes, count: count)
    }
    
    func get_shared_secret(privkey: String, pubkey: String) -> [UInt8]? {
        guard let privkey_bytes = try? privkey.bytes else {
            return nil
        }
        guard var pk_bytes = try? pubkey.bytes else {
            return nil
        }
        pk_bytes.insert(2, at: 0)
        
        var publicKey = secp256k1_pubkey()
        var shared_secret = [UInt8](repeating: 0, count: 32)

        var ok =
            secp256k1_ec_pubkey_parse(
                try! secp256k1.Context.create(),
                &publicKey,
                pk_bytes,
                pk_bytes.count) != 0

        if !ok {
            return nil
        }

        ok = secp256k1_ecdh(
            try! secp256k1.Context.create(),
            &shared_secret,
            &publicKey,
            privkey_bytes, {(output,x32,_,_) in
                memcpy(output,x32,32)
                return 1
            }, nil) != 0

        if !ok {
            return nil
        }

        return shared_secret
    }
    
    func base64_encode(_ content: [UInt8]) -> String {
        return Data(content).base64EncodedString()
    }

    func base64_decode(_ content: String) -> [UInt8]? {
        guard let dat = Data(base64Encoded: content) else {
            return nil
        }
        return dat.bytes
    }
    
    func encode_dm_base64(content: [UInt8], iv: [UInt8]) -> String {
        let content_b64 = base64_encode(content)
        let iv_b64 = base64_encode(iv)
        return content_b64 + "?iv=" + iv_b64
    }
    
    struct DirectMessageBase64 {
        let content: [UInt8]
        let iv: [UInt8]
    }
    
    func decode_dm_base64(_ all: String) -> DirectMessageBase64? {
        let splits = Array(all.split(separator: "?"))

        if splits.count != 2 {
            return nil
        }

        guard let content = base64_decode(String(splits[0])) else {
            return nil
        }

        var sec = String(splits[1])
        if !sec.hasPrefix("iv=") {
            return nil
        }

        sec = String(sec.dropFirst(3))
        guard let iv = base64_decode(sec) else {
            return nil
        }

        return DirectMessageBase64(content: content, iv: iv)
    }
    
    func aes_decrypt(data: [UInt8], iv: [UInt8], shared_sec: [UInt8]) -> Data? {
        return aes_operation(operation: CCOperation(kCCDecrypt), data: data, iv: iv, shared_sec: shared_sec)
    }
    
    // Damus version
    func encryptedEvent(
        _ message: String,
        privateKey: String
    ) throws -> Event? {
        let keyPair = try KeyPair(privateKey: privateKey)
                
        // encrypt
        let iv = random_bytes(count: 16).bytes
        guard let shared_sec = get_shared_secret(privkey: privateKey, pubkey: keyPair.publicKey) else {
            return nil
        }
        let utf8_message = Data(message.utf8).bytes
        guard let enc_message = aes_encrypt(data: utf8_message, iv: iv, shared_sec: shared_sec) else {
            return nil
        }
        let enc_content = encode_dm_base64(content: enc_message.bytes, iv: iv)
        
        let event = try Event(
            keyPair: keyPair,
            kind: .custom(4),
            tags: [.pubKey(publicKey: keyPair.publicKey)],
            content: enc_content
        )
        
        return event
    }
    
    func decryptMessage(privateKey: String, content: String) throws -> String? {
        let keyPair = try KeyPair(privateKey: privateKey)
        
        guard let shared_sec = get_shared_secret(privkey: privateKey, pubkey: keyPair.publicKey) else {
            return nil
        }
        guard let dat = decode_dm_base64(content) else {
            return nil
        }
        guard let data = aes_decrypt(data: dat.content, iv: dat.iv, shared_sec: shared_sec) else {
            return nil
        }
 
        return String(data: data, encoding: .utf8)
    }
}
