# HomeGuard Dashboard

HomeGuard is a next-generation smart home automation system that integrates advanced hardware and software to offer seamless, real-time control and monitoring of your home devices. Built around the versatile ESP8266 and a modern SwiftUI iOS app, HomeGuard delivers dynamic configuration, robust automation, and an intuitive, beautifully designed dashboard.

---

## Features

- **Centralized Control**  
  - Connect directly to your ESP8266’s dedicated Wi‑Fi network.
  - Manage multiple devices from one unified dashboard.

- **Dynamic Configuration**  
  - JSON-based configuration stored in EEPROM on the ESP8266.
  - Update the mapping of logical ports (e.g., D1, A0) to physical devices (lights, sensors, etc.) without reflashing firmware.

- **Comprehensive Device Support**  
  - Control lights, fans, doors, and more.
  - Real-time sensor data monitoring (temperature, humidity, motion, etc.).
  - Supports a range of components: PIR motion sensors, fans, LEDs, servo motors, DHT11 sensors, RFID systems, buzzers, LCD screens, and even ESP-CAM modules.
  - Expandable via an external GPIO expansion board.

- **Automation Rules**  
  - Create and manage automation rules directly within the app.
  - Rules trigger actions based on sensor readings or scheduled events.
  - Automation rules are tied to specific ports for precise control.

- **Modern User Interface**  
  - A sleek SwiftUI design featuring a splash screen, error banners, and two distinct banner sections for Automations (blue outline) and Devices (green outline).
  - Context menus allow editing, deletion, and toggling favorite status.
  - A plus-menu in the toolbar enables adding new devices or automation rules.

- **Voice Command Integration**  
  - On-device speech recognition for hands-free control.
  - Intuitive voice commands for quick device toggling and automation management.

---

## How It Works

### ESP8266 Firmware

- **Configuration Endpoint (`/config`)**  
  Accepts a JSON payload to map logical ports (e.g., "D1", "A0") to devices (e.g., light, sensor). This configuration is stored in EEPROM for persistence.

- **Command Endpoint (`/command`)**  
  Accepts HTTP requests tagged with a port and an action. For example:  
  `http://<board_ip>/command?port=D1&act=toggle`  
  The firmware looks up the port, executes the appropriate action (e.g., toggling a light), and returns a response.

- **Sensor Endpoint (`/sensor`)**  
  Returns sensor data in JSON format, mapping each configured port to its current reading (or status).

### iOS App

- **Dashboard**  
  The main screen features two banner-style sections:
  - **Automations Area:** Outlined in blue with a smart bolt icon; displays automation rules and includes a plus button to add a new rule (disabled if no devices exist).
  - **Devices Area:** Outlined in green with a plus button for adding devices (visible only when empty); devices are grouped by type and include context menus for favorite, edit, and delete actions.

- **Error Handling & Notifications**  
  A modern pop-down error banner appears if an action fails (for example, if you try to add an automation rule without any devices).

- **Real-Time Data**  
  A background polling loop retrieves live sensor data from the ESP8266, ensuring your dashboard reflects current conditions.

---

## Installation

### ESP8266 Firmware

1. **Install Arduino IDE:**  
   Download and install the latest [Arduino IDE](https://www.arduino.cc/en/software).

2. **Install ESP8266 Board Support:**  
   - Go to **File > Preferences** and add:  
     ```
     http://arduino.esp8266.com/stable/package_esp8266com_index.json
     ```
   - Open **Tools > Board > Boards Manager…**, search for “ESP8266”, and install it.

3. **Install ArduinoJson Library:**  
   - Go to **Sketch > Include Library > Manage Libraries…** and install "ArduinoJson" by Benoit Blanchon.

4. **Open and Upload Firmware:**  
   - Clone or download the `HomeGuardFirmware` folder.
   - Open `HomeGuardFirmware.ino` in the Arduino IDE.
   - Select your board (e.g., NodeMCU 1.0) and the correct port, then upload the sketch.

### iOS App

1. **Clone the Repository:**  
   Clone the GitHub repository to your local machine.

2. **Open the Xcode Project:**  
   Open the provided `.xcodeproj` or `.xcworkspace` file.

3. **Configure Global Settings:**  
   Update `globalESPIP` in `Models.swift` as needed.

4. **Run the App:**  
   Build and run the app on a simulator or physical iOS device. Ensure the device is connected to the ESP8266’s Wi‑Fi network.

---

## Usage

- **Configure Devices:**  
  Use the app’s intuitive screens to add devices by selecting the device type and a port (which corresponds to the physical GPIO on the ESP8266 or expansion board).

- **Send Commands:**  
  Tap a device row to access detailed controls or use voice commands to toggle devices.

- **Automation Rules:**  
  Create automation rules that trigger device actions based on sensor readings or scheduled timers. These rules are applied to specific ports.

- **Monitor Status:**  
  View real-time sensor data on the dashboard. Error banners inform you if any device is offline or if configuration issues occur.

---

## Future Enhancements

- **Advanced Sensor Integration:**  
  Integrate real sensor readings (e.g., DHT11, PIR, RFID) to replace dummy data.

- **Expanded Device Control:**  
  Support for additional components like servos, buzzers, LCDs, and ESP-CAM with detailed control logic.

- **Remote Configuration:**  
  Explore cloud-based configuration with Firebase for multi-device and multi-user support.

- **Enhanced Voice Recognition:**  
  Improve on-device speech recognition for more natural, hands-free control.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
