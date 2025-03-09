#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include <ArduinoJson.h>

#define EEPROM_SIZE 512
const char* apSSID = "HomeGuard_AP";
const char* apPassword = "password";
ESP8266WebServer server(80);

String configJson = "";
DynamicJsonDocument configDoc(EEPROM_SIZE);

// Global state for a test "light"
bool lightState = false;

// Helper: Map port string (e.g., "D1") to GPIO pin for a typical NodeMCU
int getGpioPin(String port) {
  port.trim();
  if (port == "D0") return 16;
  if (port == "D1") return 5;    // D1 -> GPIO5
  if (port == "D2") return 4;
  if (port == "D3") return 0;
  if (port == "D4") return 2;    // D4 is often the built-in LED (GPIO2)
  if (port == "D5") return 14;
  if (port == "D6") return 12;
  if (port == "D7") return 13;
  if (port == "D8") return 15;
  if (port == "A0") return A0;
  return -1;
}

// /config endpoint: (unchanged)
void handleConfig() {
  if (server.method() != HTTP_POST) {
    server.send(405, "text/plain", "Method Not Allowed");
    return;
  }
  String payload = server.arg("plain");
  if (payload.length() == 0) {
    server.send(400, "text/plain", "No payload received");
    return;
  }
  StaticJsonDocument<256> tempDoc;
  DeserializationError error = deserializeJson(tempDoc, payload);
  if (error) {
    server.send(400, "text/plain", "Invalid JSON");
    return;
  }
  int len = payload.length();
  if (len >= EEPROM_SIZE) {
    server.send(400, "text/plain", "Payload too large");
    return;
  }
  for (int i = 0; i < len; i++) {
    EEPROM.write(i, payload[i]);
  }
  EEPROM.write(len, '\0');
  EEPROM.commit();
  configJson = payload;
  deserializeJson(configDoc, configJson);
  Serial.println("Configuration updated: " + configJson);
  server.send(200, "text/plain", "Configuration updated");
}

// /command endpoint: now supports "status" command.
void handleCommand() {
  String port = server.arg("port");
  String act = server.arg("act");
  
  if (port.length() == 0 || act.length() == 0) {
    server.send(400, "text/plain", "Missing parameters");
    return;
  }
  
  int gpio = getGpioPin(port);
  if (gpio == -1) {
    server.send(400, "text/plain", "Invalid port");
    return;
  }
  
  // Ensure pin mode is set to OUTPUT for controlling a light.
  pinMode(gpio, OUTPUT);
  
  Serial.print("Received command on port ");
  Serial.print(port);
  Serial.print(" (GPIO ");
  Serial.print(gpio);
  Serial.print("): ");
  Serial.println(act);
  
  StaticJsonDocument<128> responseDoc;
  
  if (act == "toggle") {
    int current = digitalRead(gpio);
    int newState = (current == HIGH) ? LOW : HIGH;
    digitalWrite(gpio, newState);
    responseDoc["state"] = (newState == LOW) ? "On" : "Off";
  }
  else if (act == "lightOn") {
    digitalWrite(gpio, LOW); // Active-low: LOW = on.
    responseDoc["state"] = "On";
  }
  else if (act == "lightOff") {
    digitalWrite(gpio, HIGH);
    responseDoc["state"] = "Off";
  }
  else if (act == "status") {
    int current = digitalRead(gpio);
    responseDoc["state"] = (current == LOW) ? "On" : "Off";
  }
  else {
    server.send(400, "text/plain", "Unknown action");
    return;
  }
  
  String jsonResponse;
  serializeJson(responseDoc, jsonResponse);
  server.send(200, "application/json", jsonResponse);
}

// /sensor endpoint: Returns dummy sensor data.
void handleSensor() {
  StaticJsonDocument<200> doc;
  doc["temperature"] = 22.5;
  doc["humidity"] = 55;
  String json;
  serializeJson(doc, json);
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  EEPROM.begin(EEPROM_SIZE);
  
  // Load configuration from EEPROM (if any)
  configJson = "";
  for (int i = 0; i < EEPROM_SIZE; i++) {
    char c = EEPROM.read(i);
    if (c == '\0') break;
    configJson += c;
  }
  Serial.println("Loaded configuration: " + configJson);
  
  // Initialize built-in LED (active low) and configure test pin D1 (GPIO5).
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH); // Turn off built-in LED
  pinMode(5, OUTPUT);              // D1 -> GPIO5 for external LED
  digitalWrite(5, HIGH);           // External LED off
  
  Serial.println("Setting up Access Point...");
  WiFi.softAP(apSSID, apPassword);
  IPAddress apIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(apIP);
  
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/command", HTTP_GET, handleCommand);
  server.on("/sensor", HTTP_GET, handleSensor);
  
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}