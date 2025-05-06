//
//  DeviceCardView.swift
//  HomeGuard
//

import SwiftUI
import UniformTypeIdentifiers

struct DeviceCardView: View {
    // MARK: – Bindings & callbacks
    @Binding var device: Device
    @Binding var devices: [Device]

    @ObservedObject var logManager: EventLogManager
    var onSelect : () -> Void          // fallback tap
    var onEdit   : () -> Void          // context‑menu
    var onOpen   : (DashboardSheet) -> Void // open sheet (LED/LCD/Cam/DHT)

    // MARK: – Convenience flags
    private var isControllable: Bool {
        switch device.deviceType {
        case .light, .fan, .door, .servo, .buzzer, .statusLED: return true
        default:                                              return false
        }
    }
    private var isSensorReadingDevice: Bool {
        switch device.deviceType {
        case .temperature, .humidity, .motion, .rfid, .lcd, .espCam: return true
        default:                                                     return false
        }
    }

    // MARK: – Body
    var body: some View {
        HStack(spacing: 12) {
            // ─────────────────────────── Left: info area ───────────────────────────
            infoArea
                .contentShape(Rectangle())          // precise hit‑area
                .onTapGesture { handleTap() }

            Spacer(minLength: 4)

            // ─────────────────────────── Right: power button ───────────────────────
            if isControllable {
                PowerButton(device: $device, logManager: logManager)
                    .frame(width: 44, height: 44)   // fixed size
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

        // context‑menu only on the whole card (edit)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    // MARK: – sub‑views -------------------------------------------------------------
    private var infoArea: some View {
        HStack(spacing: 8) {
            DeviceIcon(deviceType: device.deviceType)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if isSensorReadingDevice {
                    sensorReadingView
                }
            }
        }
    }

    @ViewBuilder
    private var sensorReadingView: some View {
        if device.isOnline {
            Text(device.status)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
                .minimumScaleFactor(0.6)
        } else {
            Text("Offline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
    }

    // MARK: – Tap routing -----------------------------------------------------------
    private func handleTap() {
        switch device.deviceType {
        case .light:                   onOpen(.led(device))
        case .lcd:                     onOpen(.lcd)
        case .espCam:                  onOpen(.cam)
        case .temperature, .humidity:  onOpen(.dht)
        default:                       onSelect()
        }
    }
}

// MARK: – DeviceIcon helper --------------------------------------------------------
struct DeviceIcon: View {
    let deviceType: DeviceType
    var body: some View {
        Image(systemName: iconName(for: deviceType))
            .resizable()
            .scaledToFit()
            .foregroundColor(color(for: deviceType))
    }
    private func iconName(for type: DeviceType) -> String {
        switch type {
        case .light:        "lightbulb"
        case .fan:          "fanblades"
        case .door:         "door.closed"
        case .sensor:       "antenna.radiowaves.left.and.right"
        case .motion:       "figure.walk"
        case .servo:        "gauge"
        case .temperature:  "thermometer"
        case .humidity:     "drop"
        case .rfid:         "creditcard"
        case .lcd:          "display"
        case .buzzer:       "speaker.wave.2"
        case .espCam:       "video"
        case .statusLED:    "lock.shield"
        }
    }
    private func color(for type: DeviceType) -> Color {
        switch type {
        case .light:      .yellow
        case .fan:        .blue
        case .door:       .gray
        case .sensor:     .purple
        case .motion:     .orange
        case .servo:      .pink
        case .temperature:.red
        case .humidity:   .blue
        case .rfid:       .green
        case .lcd:        .indigo
        case .buzzer:     .red
        case .espCam:     .primary
        case .statusLED:  .green
        }
    }
}

// MARK: – Preview ------------------------------------------------------------------
struct DeviceCardView_Previews: PreviewProvider {
    @State static var devices = Device.defaultDevices()
    static var previews: some View {
        DeviceCardView(
            device: .constant(devices[0]),
            devices: .constant(devices),
            logManager: EventLogManager(),
            onSelect: { },
            onEdit:   { },
            onOpen:   { _ in }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
