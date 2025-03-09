import Foundation

struct NetworkManager {
    static func sendCommand(port: String, action: String, completion: @escaping (String?) -> Void) {
        let urlString = "http://\(globalESPIP)/command?port=\(port)&act=\(action)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending command: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                   let state = json["state"] {
                    completion(state)
                } else {
                    completion(nil)
                }
            } catch {
                print("Error decoding response: \(error)")
                completion(nil)
            }
        }.resume()
    }
}
