import Foundation
import Network

@MainActor
final class BrowserSnapshotServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastSnapshot: BrowserSnapshot?
    @Published private(set) var lastError: String?

    private let port: NWEndpoint.Port = 37717
    private let maximumRequestLength = 10_000_000
    private var listener: NWListener?

    var endpointDescription: String {
        "http://127.0.0.1:\(port.rawValue)/snapshot"
    }

    func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private nonisolated func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveRequest(on: connection, buffer: Data())
    }

    private nonisolated func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard error == nil else {
                connection.cancel()
                return
            }

            var updatedBuffer = buffer
            if let data {
                updatedBuffer.append(data)
            }

            do {
                if let body = try Self.completeRequestBody(from: updatedBuffer) {
                    self?.process(body: body, connection: connection)
                    return
                }
            } catch {
                self?.sendBadRequest(error, connection: connection)
                return
            }

            if updatedBuffer.count > (self?.maximumRequestLength ?? 10_000_000) {
                let error = NSError(
                    domain: "BrowserSnapshotServer",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Snapshot request exceeded the maximum supported size."]
                )
                self?.sendBadRequest(error, connection: connection)
                return
            }

            guard !isComplete else {
                let error = NSError(
                    domain: "BrowserSnapshotServer",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Snapshot request ended before the full HTTP body was received."]
                )
                self?.sendBadRequest(error, connection: connection)
                return
            }

            self?.receiveRequest(on: connection, buffer: updatedBuffer)
        }
    }

    nonisolated static func completeRequestBody(from data: Data) throws -> Data? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else { return nil }

        guard let header = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            throw NSError(domain: "BrowserSnapshotServer", code: 4)
        }

        let contentLength = try contentLength(from: header)
        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + contentLength
        guard data.count >= bodyEnd else { return nil }
        return data[bodyStart..<bodyEnd]
    }

    private nonisolated static func contentLength(from header: String) throws -> Int {
        for line in header.components(separatedBy: "\r\n").dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            guard parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-length" else {
                continue
            }
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if let length = Int(value), length >= 0 {
                return length
            }
            throw NSError(domain: "BrowserSnapshotServer", code: 5)
        }

        throw NSError(domain: "BrowserSnapshotServer", code: 6)
    }

    private nonisolated func process(body: Data, connection: NWConnection) {
        let response: String
        do {
            let snapshot = try JSONCoding.decoder().decode(BrowserSnapshot.self, from: body)
            Task { @MainActor in
                self.lastSnapshot = snapshot
                self.lastError = nil
            }
            response = """
            HTTP/1.1 204 No Content\r
            Access-Control-Allow-Origin: *\r
            Access-Control-Allow-Methods: POST, OPTIONS\r
            Access-Control-Allow-Headers: content-type\r
            Content-Length: 0\r
            \r
            """
        } catch {
            sendBadRequest(error, connection: connection)
            return
        }
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private nonisolated func sendBadRequest(_ error: Error, connection: NWConnection) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
        let response = """
        HTTP/1.1 400 Bad Request\r
        Access-Control-Allow-Origin: *\r
        Content-Length: 0\r
        \r
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
