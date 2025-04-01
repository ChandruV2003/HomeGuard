import SwiftUI
import UniformTypeIdentifiers

struct DeviceDropDelegate: DropDelegate {
    let item: Device
    @Binding var devices: [Device]

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else { return }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            DispatchQueue.main.async {
                guard let data = data as? Data,
                      let idString = String(data: data, encoding: .utf8),
                      let fromIndex = devices.firstIndex(where: { $0.id.uuidString == idString }),
                      let toIndex = devices.firstIndex(where: { $0.id == item.id })
                else { return }
                if fromIndex != toIndex {
                    withAnimation {
                        devices.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                    }
                }
            }
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
}
