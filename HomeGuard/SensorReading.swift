import SwiftUI
import Charts

struct SensorReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let temperatureC: Double  // Celsius
    let humidity: Double      // Percentage
}

struct DHT11ChartView: View {
    @State private var readings: [SensorReading] = []
    
    @State private var pollTimer: Timer? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Text("DHT Sensor Data")
                        .font(.title2)
                        .padding(.top)
                    
                    // Temperature Chart (Fahrenheit)
                    VStack(alignment: .leading) {
                        Text("Temperature (°F)")
                            .font(.headline)
                        Chart(readings) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp), // now using a simulated Date
                                y: .value("Temperature", celsiusToFahrenheit(reading.temperatureC))
                            )
                            .interpolationMethod(.monotone)
                        }
                        .frame(height: 200)
                    }
                    
                    // Humidity Chart
                    VStack(alignment: .leading) {
                        Text("Humidity (%)")
                            .font(.headline)
                        Chart(readings) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp), // using the simulated Date
                                y: .value("Humidity", reading.humidity)
                            )
                            .interpolationMethod(.monotone)
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("DHT11 Sensor Charts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        // The parent view can dismiss this sheet.
                    }
                }
            }
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
    
    // MARK: - Polling /sensor from the firmware
    private func startPolling() {
        // Create a timer that fires every 2 seconds to fetch new data
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            NetworkManager.fetchSensorData { jsonDict in
                guard let json = jsonDict else { return }
                // Parse the temperature and humidity from the JSON
                let tempC = parseTemperature(from: json)
                let hum   = parseHumidity(from: json)
                
                // If valid, append to readings array
                if !tempC.isNaN && !hum.isNaN {
                    // Convert simulation time to a Date based on 2023-01-01
                    let simT = json["simTime"] as? Double ?? 0
                    let newReading = SensorReading(
                        timestamp: scaledTimeToDate(simT),
                        temperatureC: tempC,
                        humidity: hum
                    )
                    readings.append(newReading)
                    
                    // Optionally keep the last 50 readings
                    if readings.count > 50 {
                        readings.removeFirst()
                    }
                }
            }
        }
    }
    
    // MARK: - Parsing JSON fields
    private func parseTemperature(from json: [String: Any]) -> Double {
        // The firmware typically returns "temperature" as a string or number
        if let tempStr = json["temperature"] as? String, let tempVal = Double(tempStr) {
            return tempVal
        } else if let tempNum = json["temperature"] as? Double {
            return tempNum
        }
        return Double.nan
    }
    
    private func parseHumidity(from json: [String: Any]) -> Double {
        if let humStr = json["humidity"] as? String, let humVal = Double(humStr) {
            return humVal
        } else if let humNum = json["humidity"] as? Double {
            return humNum
        }
        return Double.nan
    }
    
    // MARK: - Celsius to Fahrenheit
    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9.0 / 5.0 + 32.0
    }
    
    // MARK: - Convert Simulation Time to Date
    /// Converts simulation time (in milliseconds) to a "fake" Date,
    /// offset from January 1, 2023 (00:00:00 GMT).
    private func scaledTimeToDate(_ scaledMillis: Double) -> Date {
        let baseEpoch: TimeInterval = 1672531200 // 2023-01-01 00:00:00 GMT
        return Date(timeIntervalSince1970: baseEpoch + scaledMillis / 1000.0)
    }
}

struct DHT11ChartView_Previews: PreviewProvider {
    static var previews: some View {
        DHT11ChartView()
    }
}
