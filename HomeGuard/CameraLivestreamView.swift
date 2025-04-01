import SwiftUI
import UIKit

/// ViewModel that handles parsing an MJPEG stream and providing
/// the current frame as a UIImage.
class MjpegStreamViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    /// The latest frame from the stream.
    @Published var image: UIImage?

    private var dataTask: URLSessionDataTask?
    private var session: URLSession?
    private var currentData = Data()

    // The boundary in your ESP32-CAM stream (set in firmware).
    // The firmware sends "boundary=frame", so we look for "--frame".
    private let boundaryString = "--frame"

    // Starts streaming from the given URL.
    func startStreaming(url: URL) {
        let config = URLSessionConfiguration.default
        // Make sure the session doesn't timeout, since this is a continuous stream.
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity

        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        dataTask = session?.dataTask(with: url)
        dataTask?.resume()
    }

    // Stops the streaming session.
    func stopStreaming() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionDataDelegate

    // Continuously called as chunks of data arrive from the stream.
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        // Append the newly received data to our buffer.
        currentData.append(data)

        // Look for our boundary string in the current data.
        while let boundaryRange = currentData.range(of: boundaryData()) {
            // Extract data up to (but not including) the boundary as one frame chunk.
            let frameData = currentData[..<boundaryRange.lowerBound]

            // Remove that chunk + boundary from our buffer.
            currentData.removeSubrange(..<boundaryRange.upperBound)

            // Attempt to find the JPEG and convert it to a UIImage.
            if let image = extractJPEG(from: frameData) {
                DispatchQueue.main.async {
                    // Publish the new frame so the UI can update.
                    self.image = image
                }
            }
        }
    }

    // Convert the boundary string to Data for searching.
    private func boundaryData() -> Data {
        boundaryString.data(using: .utf8) ?? Data()
    }

    // Tries to find a complete JPEG (FF D8 ... FF D9) inside a chunk.
    private func extractJPEG(from data: Data) -> UIImage? {
        // The start of a JPEG is 0xFF 0xD8, the end is 0xFF 0xD9.
        guard
            let startRange = data.range(of: Data([0xFF, 0xD8])),
            let endRange   = data.range(of: Data([0xFF, 0xD9]),
                                options: [],
                                in: startRange.lowerBound..<data.endIndex)
        else {
            return nil
        }

        // Extract the JPEG data from start to end (inclusive).
        let jpegData = data[startRange.lowerBound..<endRange.upperBound]
        return UIImage(data: jpegData)
    }
}

/// SwiftUI view that displays an MJPEG stream from an ESP32-CAM.
/// It starts parsing the stream when the view appears, and stops when it disappears.
struct CameraLivestreamView: View {
    let streamURL: URL

    @StateObject private var viewModel = MjpegStreamViewModel()

    var body: some View {
        GeometryReader { geometry in
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
                    .clipped()
            } else {
                Text("Loading Stream...")
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        // Start streaming when the view appears.
        .onAppear {
            viewModel.startStreaming(url: streamURL)
        }
        // Stop streaming when the view disappears (e.g. navigates away).
        .onDisappear {
            viewModel.stopStreaming()
        }
    }
}

struct CameraLivestreamView_Previews: PreviewProvider {
    static var previews: some View {
        // Change to your actual ESP32-CAM IP and port
        CameraLivestreamView(streamURL: URL(string: "http://192.168.4.2:81/stream")!)
    }
}
