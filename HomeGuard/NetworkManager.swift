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
    
    // 3) Automations
    static func sendAutomationRule(rule: AutomationRule, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/add_rule") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let json: [String: Any] = [
            "name": rule.name,
            "condition": rule.condition,
            "action": rule.action,
            "activeDays": rule.activeDays,
            "triggerEnabled": rule.triggerEnabled,
            "triggerTime": rule.triggerTime.timeIntervalSince1970
        ]
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
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(nil)
                return
            }
            let decoder = JSONDecoder()
            if let rules = try? decoder.decode([AutomationRule].self, from: data) {
                completion(rules)
            } else {
                completion(nil)
            }
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
    
    // 5) Security
    static func sendSecuritySettings(message: String, duration: Int, completion: @escaping (Bool) -> Void) {
        guard let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://\(Config.globalESPIP)/security?msg=\(encodedMessage)&duration=\(duration)")
        else {
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
