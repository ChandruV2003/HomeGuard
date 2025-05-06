import SwiftUI
import UIKit

class MjpegStreamViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    // The latest frame from the stream.
    @Published var image: UIImage?

    private var dataTask: URLSessionDataTask?
    private var session: URLSession?
    private var currentData = Data()
    
    // The boundary in your ESP32-CAM stream (set in firmware).
    private let boundaryString = "--frame\r\n"
    
    // Parser state for the multipart stream.
    enum MJPEGParseState {
        case lookingForBoundary
        case readingHeaders
        case readingImageData(expectedLength: Int)
    }
    private var parserState: MJPEGParseState = .lookingForBoundary

    // Change this constant to control how much data is allowed before fallback extraction.
    private let fallbackBufferThreshold = 200_000   // Adjust this value (e.g., 200,000 bytes ~ one second's worth)

    // Use a serial delegate queue to avoid concurrent modifications.
    private let serialQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // MARK: - Streaming Methods

    func startStreaming(url: URL) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity

        // Initialize URLSession with the serial delegate queue.
        session = URLSession(configuration: config, delegate: self, delegateQueue: serialQueue)
        dataTask = session?.dataTask(with: url)
        dataTask?.resume()
    }

    func stopStreaming() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        // Append new data – safe because we are on our serial queue.
        currentData.append(data)
        print("Received \(data.count) bytes, currentData length: \(currentData.count)")
        
        processBuffer()
    }
    
    /// Process the accumulated data using our state machine. If no boundary is found and the data grows too large,
    /// use a fallback that looks for JPEG start (FF D8) and end (FF D9) markers.
    private func processBuffer() {
        while true {
            switch parserState {
            case .lookingForBoundary:
                if let boundaryRange = currentData.range(of: boundaryString.data(using: .utf8)!) {
                    print("Boundary found at range: \(boundaryRange)")
                    // Remove everything up to and including the boundary.
                    currentData.removeSubrange(..<boundaryRange.upperBound)
                    parserState = .readingHeaders
                    print("State changed to: readingHeaders")
                } else {
                    // If we haven't found a boundary and the buffer is too large, use fallback extraction.
                    if currentData.count > fallbackBufferThreshold {
                        print("Buffer too large (\(currentData.count) bytes) without boundary; attempting fallback extraction.")
                        if let start = currentData.range(of: Data([0xFF, 0xD8])),
                           let end = currentData.range(of: Data([0xFF, 0xD9]), options: [], in: start.lowerBound..<currentData.endIndex) {
                            let jpegData = currentData[start.lowerBound..<end.upperBound]
                            currentData.removeSubrange(0..<end.upperBound)
                            if let image = UIImage(data: jpegData) {
                                DispatchQueue.main.async {
                                    self.image = image
                                }
                                print("Image extracted via fallback")
                            } else {
                                print("Fallback: failed to create image from data")
                            }
                        }
                    }
                    // Boundary not found; wait for more data.
                    return
                }
                
            case .readingHeaders:
                // Look for the header terminator (\r\n\r\n).
                if let headerEndRange = currentData.range(of: "\r\n\r\n".data(using: .utf8)!) {
                    let headerData = currentData.prefix(headerEndRange.lowerBound)
                    guard let headerString = String(data: headerData, encoding: .utf8) else {
                        print("Failed to decode header")
                        currentData.removeSubrange(..<headerEndRange.upperBound)
                        parserState = .lookingForBoundary
                        continue
                    }
                    print("Header found: \(headerString)")
                    
                    // Parse the headers for Content-Length.
                    let lines = headerString.components(separatedBy: "\r\n")
                    var contentLength: Int?
                    for line in lines {
                        if line.lowercased().hasPrefix("content-length") {
                            let parts = line.components(separatedBy: ":")
                            if parts.count > 1, let length = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                                contentLength = length
                                break
                            }
                        }
                    }
                    
                    if let contentLength = contentLength {
                        print("Parsed Content-Length: \(contentLength)")
                        // Remove the header block.
                        currentData.removeSubrange(..<headerEndRange.upperBound)
                        parserState = .readingImageData(expectedLength: contentLength)
                        print("State changed to: readingImageData(expectedLength: \(contentLength))")
                    } else {
                        print("Content-Length not found in header: \(headerString)")
                        currentData.removeSubrange(..<headerEndRange.upperBound)
                        parserState = .lookingForBoundary
                    }
                } else {
                    // Incomplete header; wait for more data.
                    return
                }
                
            case .readingImageData(let expectedLength):
                if currentData.count >= expectedLength {
                    let imageData = currentData.prefix(expectedLength)
                    currentData.removeSubrange(0..<expectedLength)
                    
                    // Optionally remove trailing CRLF if present.
                    if currentData.starts(with: "\r\n".data(using: .utf8)!) {
                        currentData.removeSubrange(0..<2)
                    }
                    
                    print("Attempting to create image from \(expectedLength) bytes")
                    if let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.image = image
                        }
                        print("Image created successfully")
                    } else {
                        print("Failed to create image from data")
                        let hexString = imageData.prefix(10).map { String(format:"%02hhx", $0) }.joined(separator: " ")
                        print("Image data first bytes: \(hexString)")
                    }
                    
                    // Reset state for the next frame.
                    parserState = .lookingForBoundary
                    print("State reset to: lookingForBoundary")
                } else {
                    // Not enough data yet; wait for more.
                    return
                }
            }
        }
    }
    
    // Called when the streaming task completes.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Stream completed with error: \(error.localizedDescription)")
        } else {
            print("Stream completed successfully")
        }
    }
}

struct CameraLivestreamView: View {
    let streamURL: URL
    @StateObject private var viewModel = MjpegStreamViewModel()

    var body: some View {
        GeometryReader { geo in
            // ②  guarantee a minimum frame > 0 during sheet animation
            ZStack {
                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView("Loading Stream…")
                }
            }
            .frame(
                width: max(geo.size.width, 1),
                height: max(geo.size.height, 1)
            )
        }
        .onAppear { viewModel.startStreaming(url: streamURL) }
        .onDisappear { viewModel.stopStreaming() }
    }
}

struct CameraLivestreamView_Previews: PreviewProvider {
    static var previews: some View {
        CameraLivestreamView(streamURL: URL(string: "http://172.20.10.6:81/stream")!)
    }
}
