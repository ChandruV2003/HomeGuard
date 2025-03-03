#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <DHT.h>

// ----- Sensor Setup -----
#define DHTPIN D4        // Connect the sensor data pin to GPIO D4
#define DHTTYPE DHT22    // Use DHT22 (change to DHT11 if needed)
DHT dht(DHTPIN, DHTTYPE);

// Global sensor data variables
float temperature = 0.0;
float humidity = 0.0;

// ----- WiFi Configuration -----
// Option A: Access Point Mode
const char* apSSID = "HomeGuard_AP";
const char* apPassword = "password";

// Uncomment the following for Station Mode instead:
// const char* ssid = "YourNetworkSSID";
// const char* password = "YourNetworkPassword";

// ----- Web Server Setup -----
ESP8266WebServer server(80);

// ----- Endpoint Handlers -----
// /command endpoint: expects "act" parameter
void handleCommand() {
  if (!server.hasArg("act")) {
    server.send(400, "text/plain", "Missing 'act' parameter");
    return;
  }
  String action = server.arg("act");
  Serial.print("Received command: ");
  Serial.println(action);
  
  if (action == "lightOn") {
    digitalWrite(LED_BUILTIN, LOW);  // Turn LED on (active low)
    server.send(200, "text/plain", "Light turned on");
  } else if (action == "lightOff") {
    digitalWrite(LED_BUILTIN, HIGH); // Turn LED off
    server.send(200, "text/plain", "Light turned off");
  } else if (action == "garageOpen") {
    // Insert your garage control code here.
    server.send(200, "text/plain", "Garage opened");
  } else if (action == "garageClose") {
    // Insert your garage control code here.
    server.send(200, "text/plain", "Garage closed");
  } else {
    server.send(400, "text/plain", "Unknown command");
  }
}

// /sensor endpoint: returns sensor data as JSON
void handleSensor() {
  String json = "{\"temperature\":" + String(temperature, 1) +
                ", \"humidity\":" + String(humidity, 1) + "}";
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  // Initialize DHT sensor
  dht.begin();
  
  // Initialize the built-in LED (often active low)
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);
  
  // ----- WiFi Setup -----
  // Option A: Access Point Mode
  Serial.println("Setting up as an Access Point...");
  WiFi.softAP(apSSID, apPassword);
  IPAddress apIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(apIP);
  
  // Option B: Station Mode (uncomment to use)
  /*
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  */
  
  // ----- Set up HTTP Endpoints -----
  server.on("/command", HTTP_GET, handleCommand);
  server.on("/sensor", HTTP_GET, handleSensor);
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  /*
  // Update sensor data every 2 seconds.
  static unsigned long lastSensorRead = 0;
  if (millis() - lastSensorRead > 2000) {
    float newHumidity = dht.readHumidity();
    float newTemp = dht.readTemperature();  // Temperature in Celsius
    if (isnan(newHumidity) || isnan(newTemp)) {
      Serial.println("Failed to read from DHT sensor!");
    } else {
      humidity = newHumidity;
      temperature = newTemp;
      Serial.print("Temperature: ");
      Serial.print(temperature);
      Serial.print("°C, Humidity: ");
      Serial.print(humidity);
      Serial.println("%");
    }
    lastSensorRead = millis();
  }
  */
  
  // Handle HTTP requests.
  server.handleClient();
}