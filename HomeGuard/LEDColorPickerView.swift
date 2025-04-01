import SwiftUI

/// A simple color picker sheet for controlling a FastLED-based strip.
struct LEDColorPickerView: View {
    /// The device's port (e.g. "GPIO32" or "GPIO33")
    var devicePort: String
    
    /// Callback when user closes this picker
    var onDismiss: () -> Void
    
    /// The currently selected SwiftUI color
    @State private var selectedColor: Color = .white
    
    /// Brightness factor (0..1)
    @State private var brightness: Double = 1.0
    
    /// Whether to close after sending the color
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("LED Color")) {
                    ColorPicker("Select LED Color", selection: $selectedColor, supportsOpacity: false)
                }
                
                Section(header: Text("Brightness")) {
                    Slider(value: $brightness, in: 0...1, step: 0.05)
                    Text("\(Int(brightness * 100))%")
                        .font(.caption)
                }
                
                Button("Update LED Color") {
                    let hex = colorToHex(selectedColor, brightness: brightness)
                    
                    // Example call to /command?port=GPIOxx&act=setColor&color=RRGGBB
                    NetworkManager.sendCommand(
                        port: devicePort,
                        action: "setColor",
                        extraParams: ["color": hex]
                    ) { newState in
                        print("Response from setColor: \(newState ?? "no response")")
                    }
                    
                    // Dismiss the sheet
                    onDismiss()
                }
            }
            .navigationTitle("LED Color Picker")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    /// Convert the selected SwiftUI Color + brightness to a hex string "RRGGBB".
    private func colorToHex(_ color: Color, brightness: Double) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Apply brightness factor
        r *= CGFloat(brightness)
        g *= CGFloat(brightness)
        b *= CGFloat(brightness)
        
        let R = Int(r * 255)
        let G = Int(g * 255)
        let B = Int(b * 255)
        
        return String(format: "%02X%02X%02X", R, G, B)
    }
}

struct LEDColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LEDColorPickerView(devicePort: "GPIO32", onDismiss: {})
    }
}
