import Foundation

struct SyncManager {
    // Checks connectivity by calling the /ping endpoint.
    static func checkConnection(globalIP: String,
                                completion: @escaping (Bool) -> Void) {
        var comp = URLComponents(string: "http://\(globalIP)/ping")!
        comp.queryItems = NetworkManager.authItems()      // <– add this
        URLSession.shared.dataTask(with: comp.url!) { _, resp, err in
            DispatchQueue.main.async {
                let ok = (resp as? HTTPURLResponse)?.statusCode == 200 && err == nil
                completion(ok)
            }
        }.resume()
    }
    
    // Optionally, you can add additional sync tasks here (e.g., fetch sensor data)
    static func fetchSensorData(globalIP: String, completion: @escaping (SensorData?) -> Void) {
        guard let url = URL(string: "http://\(globalIP)/sensor") else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data else { completion(nil); return }
                let decoder = JSONDecoder()
                if let sensorData = try? decoder.decode(SensorData.self, from: data) {
                    completion(sensorData)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}
