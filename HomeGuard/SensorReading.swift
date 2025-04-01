import SwiftUI
import Charts

/// A single sensor reading, with timestamp, temperature (Celsius), and humidity (%).
struct SensorReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let temperatureC: Double  // Celsius
    let humidity: Double      // Percentage
}

/// The chart view that fetches real DHT data from the firmware’s /sensor endpoint.
struct DHT11ChartView: View {
    /// The array of historical readings. We update this with real data.
    @State private var readings: [SensorReading] = []
    
    /// A timer to poll the firmware. We'll invalidate it when leaving the view.
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
                                x: .value("Time", reading.timestamp),
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
                                x: .value("Time", reading.timestamp),
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
                // Attempt to parse the temperature/humidity from the JSON
                let tempC = parseTemperature(from: json)
                let hum   = parseHumidity(from: json)
                
                // If valid, append to readings array
                if !tempC.isNaN && !hum.isNaN {
                    let newReading = SensorReading(
                        timestamp: Date(),
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
        }
        else if let tempNum = json["temperature"] as? Double {
            return tempNum
        }
        return Double.nan
    }
    
    private func parseHumidity(from json: [String: Any]) -> Double {
        if let humStr = json["humidity"] as? String, let humVal = Double(humStr) {
            return humVal
        }
        else if let humNum = json["humidity"] as? Double {
            return humNum
        }
        return Double.nan
    }
    
    // MARK: - Celsius to Fahrenheit
    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9.0 / 5.0 + 32.0
    }
}

struct DHT11ChartView_Previews: PreviewProvider {
    static var previews: some View {
        DHT11ChartView()
    }
}
