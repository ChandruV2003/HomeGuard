//
//  DevicesAreaView.swift
//  HomeGuard
//

import SwiftUI
import UniformTypeIdentifiers

struct DevicesAreaView: View {
    // MARK: – Inputs
    @Binding var devices: [Device]
    var onSelect       : (Device) -> Void
    var onContextAction: (Device, DeviceContextAction) -> Void
    var onOpenSheet    : (DashboardSheet) -> Void
    @ObservedObject var logManager: EventLogManager
    var isReordering = false       // drag mode

    // MARK: – Layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    // MARK: – Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            banner

            if devices.isEmpty {
                Text("No devices available.")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                // ①  NO INNER SCROLLVIEW  – parent Dashboard scrolls everything.
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sortedDeviceTypes, id: \.self) { type in
                        ForEach(groupedDeviceTypes[type] ?? []) { device in
                            if let binding = binding(for: device) {
                                buildCard(for: binding, device: device)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: – Banner
    private var banner: some View {
        HStack {
            Image(systemName: "desktopcomputer").foregroundColor(.green)
            Text("Devices").font(.headline).foregroundColor(.green)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green, lineWidth: 2)
        )
    }

    // MARK: – Helper builders
    private func buildCard(for binding: Binding<Device>, device: Device) -> some View {
        let card = DeviceCardView(
            device: binding,
            devices: $devices,
            logManager: logManager,
            onSelect:        { onSelect(device) },
            onEdit:          { onContextAction(device, .edit) },
            onOpen:          onOpenSheet
        )

        // Drag / drop only while re‑ordering
        return Group {
            if isReordering {
                card
                    .onDrag { NSItemProvider(object: device.id.uuidString as NSString) }
                    .onDrop(
                        of: [UTType.text.identifier],
                        delegate: DeviceDropDelegate(item: device, devices: $devices)
                    )
            } else {
                card
            }
        }
    }

    // MARK: – Grouping helpers
    private var groupedDeviceTypes: [DeviceType: [Device]] {
        Dictionary(grouping: devices, by: \.deviceType)
    }
    private var sortedDeviceTypes: [DeviceType] {
        groupedDeviceTypes.keys.sorted { $0.rawValue < $1.rawValue }
    }
    private func binding(for device: Device) -> Binding<Device>? {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return nil }
        return $devices[idx]
    }
}

struct DevicesAreaView_Previews: PreviewProvider {
    @State static var devices = Device.defaultDevices()
    static var previews: some View {
        DevicesAreaView(
            devices: $devices,
            onSelect: { _ in },
            onContextAction: { _,_ in },
            onOpenSheet: { _ in },
            logManager: EventLogManager()
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
