import Foundation
import CryptoKit

// ──────────────────────────────────────────────────────────────
// Rolling‑code (TOTP‑style) helper
// ──────────────────────────────────────────────────────────────
fileprivate let authKey = SymmetricKey(data: Data([
    0x8f, 0x1d, 0x46, 0xee, 0x62, 0x7a, 0x99, 0xeb,
    0x13, 0x4c, 0x55, 0xa9, 0x0d, 0x31, 0xbc, 0xcd,
    0xaa, 0x44, 0x20, 0x74            // ← use your own 160‑bit key
]))
fileprivate let stepSec: TimeInterval = 10      // code changes every 10 s

/// 6‑digit code valid for the current `stepSec` window.
fileprivate func rollingCode() -> String {
    let counter = UInt64(Date().timeIntervalSince1970 / stepSec)
    var be = counter.bigEndian                    // 8‑byte BE value
    let mac = HMAC<Insecure.SHA1>.authenticationCode(
        for: Data(bytes: &be, count: 8), using: authKey)

    // RFC 4226 dynamic truncation (alignment‑safe)
    let digest = Array(mac)                       // [UInt8] – 20 bytes
    let offset = Int(digest[19] & 0x0F)
    var bin: UInt32 =
        (UInt32(digest[offset    ]) & 0x7F) << 24 |
        (UInt32(digest[offset + 1]) & 0xFF) << 16 |
        (UInt32(digest[offset + 2]) & 0xFF) <<  8 |
        (UInt32(digest[offset + 3]) & 0xFF)

    bin = bin % 1_000_000                         // 6 digits
    return String(format: "%06u", bin)
}

// ──────────────────────────────────────────────────────────────
// Main struct
// ──────────────────────────────────────────────────────────────
struct NetworkManager {

    // Legacy token kept during migration
    private static let secretToken =
        "75ae7d29ec27cf2eb6482b37eb66fa14933b7fffc53c6e91727f7e2c642f9b59"

    /// Prepends `token` + rolling `code` to every call
    @inline(__always)
    static func authItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: "token", value: secretToken),
            URLQueryItem(name: "code",  value: rollingCode())
        ]
    }

    // ----------------------------------------------------------
    // 1)  /command
    // ----------------------------------------------------------
    static func sendCommand(
        port: String,
        action: String,
        extraParams: [String: String] = [:],
        completion: @escaping (String?) -> Void = { _ in }
    ) {

        var items = authItems() +
            [
                URLQueryItem(name: "port", value: port),
                URLQueryItem(name: "act",  value: action)
            ]
        for (k, v) in extraParams { items.append(.init(name: k, value: v)) }

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/command")!
        comp.queryItems = items
        var request = URLRequest(url: comp.url!)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard
                error == nil,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                let state = json["state"]
            else { completion(nil); return }
            completion(state)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 2)  /sensor
    // ----------------------------------------------------------
    static func fetchSensorData(completion: @escaping ([String: Any]?) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/sensor")!
        comp.queryItems = authItems()

        URLSession.shared.dataTask(with: comp.url!) { data, _, error in
            guard
                error == nil,
                let data = data,
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { completion(nil); return }
            completion(dict)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 3)  /add_rule   (POST)
    // ----------------------------------------------------------
    // Replace the existing declaration in NetworkManager.swift
    // (around the “/add_rule” section) with this one ↓

    static func sendAutomationRule(
        rule: AutomationRule,                    // <-- label restored
        completion: @escaping (Bool) -> Void
    ) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/add_rule")!
        comp.queryItems = authItems()

        let triggerTimeInt = Int(rule.triggerTime.timeIntervalSince1970)
        var body: [String: Any] = [
            "uid":            rule.id,
            "name":           rule.name,
            "condition":      rule.condition,
            "action":         rule.action,
            "activeDays":     rule.activeDays,
            "triggerEnabled": rule.triggerEnabled,
            "triggerTime":    triggerTimeInt
        ]
        if let id = rule.inputDeviceID  { body["inputDeviceID"]  = id }
        if let id = rule.outputDeviceID { body["outputDeviceID"] = id }

        var request = URLRequest(url: comp.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }


    // ----------------------------------------------------------
    // 4)  /get_rules
    // ----------------------------------------------------------
    static func fetchAutomationRules(completion: @escaping ([AutomationRule]?) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/get_rules")!
        comp.queryItems = authItems()

        URLSession.shared.dataTask(with: comp.url!) { data, _, error in
            guard let data = data, error == nil else { completion(nil); return }
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
            completion(try? dec.decode([AutomationRule].self, from: data))
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 5)  /delete_rule
    // ----------------------------------------------------------
    static func deleteAutomationRule(uid: String, completion: @escaping (Bool) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/delete_rule")!
        comp.queryItems = authItems() + [.init(name: "uid", value: uid)]

        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 6)  /toggle_rule
    // ----------------------------------------------------------
    static func toggleAutomationRule(uid: String, completion: @escaping (Bool) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/toggle_rule")!
        comp.queryItems = authItems() + [.init(name: "uid", value: uid)]

        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 7)  /lcd
    // ----------------------------------------------------------
    static func sendLCDMessage(message: String,
                               duration: Int,
                               completion: @escaping (Bool) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/lcd")!
        comp.queryItems = authItems() + [
            .init(name: "msg",      value: message),
            .init(name: "duration", value: String(duration))
        ]

        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 8)  /security
    // ----------------------------------------------------------
    static func sendSecuritySettings(
        goodCard: String,
        badCard: String,
        grantedMsg: String,
        deniedMsg: String,
        buzzerMs: Int,
        completion: @escaping (Bool) -> Void
    ) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/security")!
        comp.queryItems = authItems() + [
            .init(name: "good",     value: goodCard),
            .init(name: "bad",      value: badCard),
            .init(name: "granted",  value: grantedMsg),
            .init(name: "denied",   value: deniedMsg),
            .init(name: "buzzerMs", value: String(buzzerMs))
        ]

        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }

    // ----------------------------------------------------------
    // 9)  /led
    // ----------------------------------------------------------
    static func sendLEDCommand(strip: Int,
                               color: String,
                               completion: @escaping (Bool) -> Void) {

        var comp = URLComponents(string: "http://\(Config.globalESPIP)/led")!
        comp.queryItems = authItems() + [
            .init(name: "strip", value: String(strip)),
            .init(name: "color", value: color)
        ]

        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            completion((resp as? HTTPURLResponse)?.statusCode == 200 && err == nil)
        }
        .resume()
    }
}
