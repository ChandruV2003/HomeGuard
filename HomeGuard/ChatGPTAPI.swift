//
//  ChatGPTAPI.swift
//  HomeGuard
//
//  Created by Shrinivas Sai on 4/1/25.
//
import Foundation

class ChatGPTAPI {
        static func fetchAutomation(prompt: String, completion: @escaping (AutomationRule?) -> Void) {
        let apiKey = "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"  // Keep your API key here
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  let automationData = content.data(using: .utf8),
                  let automation = try? JSONDecoder().decode(AutomationRule.self, from: automationData)
            else {
                completion(nil)
                return
            }
            completion(automation)
        }.resume()
    }
}
