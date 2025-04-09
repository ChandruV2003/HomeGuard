import Foundation

struct NetworkManager {
    
    // 1) Command endpoint
    static func sendCommand(
        port: String,
        action: String,
        extraParams: [String: String] = [:],
        completion: @escaping (String?) -> Void = { _ in }
    ) {
        var queryItems = [
            URLQueryItem(name: "port", value: port),
            URLQueryItem(name: "act", value: action)
        ]
        for (k, v) in extraParams {
            queryItems.append(URLQueryItem(name: k, value: v))
        }
        guard let baseURL = URL(string: "http://\(Config.globalESPIP)/command") else {
            completion(nil)
            return
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        guard let finalURL = components.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending command: \(error)")
                completion(nil)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                  let state = json["state"] else {
                completion(nil)
                return
            }
            completion(state)
        }.resume()
    }
    
    // 2) /sensor data
    static func fetchSensorData(completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/sensor") else {
            completion(nil)
            return
        }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let data = data,
                  let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            else {
                completion(nil)
                return
            }
            completion(jsonDict)
        }.resume()
    }
    
    // 3) sendAutomationRule => POST /add_rule
    static func sendAutomationRule(rule: AutomationRule, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/add_rule") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Convert the Swift rule's .id to the "uid" field
        let triggerTimeInt = Int(rule.triggerTime.timeIntervalSince1970)

        var json: [String: Any] = [
            "uid": rule.id,  // <--- pass the same UUID string
            "name": rule.name,
            "condition": rule.condition,
            "action": rule.action,
            "activeDays": rule.activeDays,
            "triggerEnabled": rule.triggerEnabled,
            "triggerTime": triggerTimeInt
        ]
        // If we have inputDeviceID / outputDeviceID:
        if let inDev = rule.inputDeviceID {
            json["inputDeviceID"] = inDev
        }
        if let outDev = rule.outputDeviceID {
            json["outputDeviceID"] = outDev
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            completion(success)
        }.resume()
    }

    
    static func fetchAutomationRules(completion: @escaping ([AutomationRule]?) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/get_rules") else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Fetch automation rules error: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
                return
            }
            let decoder = JSONDecoder()
            // Use secondsSince1970 (or millisecondsSince1970 if that’s what your firmware uses)
            decoder.dateDecodingStrategy = .secondsSince1970
            if let rules = try? decoder.decode([AutomationRule].self, from: data) {
                completion(rules)
            } else {
                // Print the raw JSON to help debug what is coming back.
                let raw = String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
                print("Decoding failed for automation rules. Data: \(raw)")
                completion(nil)
            }
        }.resume()
    }
    
    static func deleteAutomationRule(uid: String, completion: @escaping (Bool) -> Void) {
        // Build URL with uid instead of rule name
        guard let url = URL(string: "http://\(Config.globalESPIP)/delete_rule?uid=\(uid)") else {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            completion(success)
        }.resume()
    }

    
    static func toggleAutomationRule(uid: String, completion: @escaping (Bool) -> Void) {
        // E.g. "http://192.168.4.1/toggle_rule?uid=ACEC2339..."
        let urlString = "http://\(Config.globalESPIP)/toggle_rule?uid=\(uid)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { _, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && (error == nil)
            completion(success)
        }.resume()
    }


    
    // 4) LCD
    static func sendLCDMessage(message: String, duration: Int, completion: @escaping (Bool) -> Void) {
        guard let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://\(Config.globalESPIP)/lcd?msg=\(encodedMessage)&duration=\(duration)")
        else {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { _, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            completion(success)
        }.resume()
    }
    
    // 5) Security: /security?good=...&bad=...&granted=...&denied=...&buzzerMs=...
    static func sendSecuritySettings(
        goodCard: String,
        badCard: String,
        grantedMsg: String,
        deniedMsg: String,
        buzzerMs: Int,
        completion: @escaping (Bool) -> Void
    ) {
        var comp = URLComponents(string: "http://\(Config.globalESPIP)/security")!
        comp.queryItems = [
            URLQueryItem(name: "good", value: goodCard),
            URLQueryItem(name: "bad", value: badCard),
            URLQueryItem(name: "granted", value: grantedMsg),
            URLQueryItem(name: "denied", value: deniedMsg),
            URLQueryItem(name: "buzzerMs", value: String(buzzerMs))
        ]
        guard let url = comp.url else {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { _, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            completion(success)
        }.resume()
    }
    
    // 6) LED
    static func sendLEDCommand(strip: Int, color: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/led?strip=\(strip)&color=\(color)") else {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { _, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            completion(success)
        }.resume()
    }
}
