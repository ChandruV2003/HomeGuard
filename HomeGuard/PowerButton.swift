//
//  PowerButton.swift
//  HomeGuard
//

import SwiftUI

struct PowerButton: View {
    // ────────── bindings / managers
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager

    // ────────── env / state
    @Environment(\.colorScheme) private var colorScheme
    @State private var isBusy = false

    // ────────── constants
    private let circleSize: CGFloat = 44
    private var isOffline: Bool { !device.isOnline }

    // ────────── body
    var body: some View {
        Button(action: toggleDevice) {
            ZStack {
                // background circle
                Circle()
                    .fill(backgroundColor)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor,
                            radius: isOffline ? 0 : 2,
                            x: 0, y: 1)

                // icon or spinner
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(iconColor)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }
        }
        .contentShape(Circle())                 // enlarge hit‑area
        .frame(width: circleSize, height: circleSize)
        .buttonStyle(.plain)
        .disabled(isBusy || isOffline)          // unpressable if offline
    }

    // ────────── visuals
    private var backgroundColor: Color {
        if isOffline {
            return Color(UIColor.secondarySystemBackground)   // inset look
        }
        return device.isOn ? .green : .gray
    }
    private var borderColor: Color {
        isOffline ? Color.gray.opacity(0.4) : .clear
    }
    private var shadowColor: Color {
        isOffline ? .clear : Color.black.opacity(0.25)
    }
    private var iconColor: Color {
        isOffline ? .gray : .white
    }

    // ────────── toggle logic (unchanged)
    private func toggleDevice() {
        guard device.isOnline, !isBusy else { return }
        isBusy = true

        NetworkManager.sendCommandWithRetry(
            port: device.port,
            action: "toggle"
        ) { state, ok in
            DispatchQueue.main.async {
                defer { isBusy = false }
                guard ok, let state = state else {
                    logManager.addLog("⚠️  \(device.name) did not respond")
                    return
                }

                // Update local model based on returned state
                switch device.deviceType {
                case .door, .servo:
                    device.status = state
                    device.isOn   = (state == "Opened")

                case .light, .fan, .buzzer:
                    device.isOn   = (state == "On")
                    device.status = device.isOn ? "On" : "Off"

                default:
                    device.isOn.toggle()
                    device.status = device.isOn ? "On" : "Off"
                }

                logManager.addLog("\(device.name) → \(device.status)")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Preview
// ─────────────────────────────────────────────────────────────

struct PowerButton_Previews: PreviewProvider {
    @State static var sampleDevice = Device.create(
        name: "Kitchen Lights",
        status: "On",
        deviceType: .light,
        port: "GPIO32"
    )
    static var previews: some View {
        VStack(spacing: 20) {
            PowerButton(device: $sampleDevice, logManager: EventLogManager()) // online / on
            PowerButton(device: .constant({ var d = sampleDevice; d.isOn = false; return d }()),
                        logManager: EventLogManager())                       // online / off
            PowerButton(device: .constant({ var d = sampleDevice; d.isOnline = false; return d }()),
                        logManager: EventLogManager())                       // offline
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
