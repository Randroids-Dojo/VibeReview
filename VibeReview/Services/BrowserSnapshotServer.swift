import Foundation
import Network

@MainActor
final class BrowserSnapshotServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastSnapshot: BrowserSnapshot?
    @Published private(set) var lastError: String?

    private let port: NWEndpoint.Port = 37717
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_000_000) { [weak self] data, _, _, _ in
            guard let data else {
                connection.cancel()
                return
            }
            self?.process(data, connection: connection)
        }
    }

    private nonisolated func process(_ data: Data, connection: NWConnection) {
        let response: String
        do {
            guard let request = String(data: data, encoding: .utf8),
                  let bodyStart = request.range(of: "\r\n\r\n")?.upperBound else {
                throw NSError(domain: "BrowserSnapshotServer", code: 1)
            }
            let body = Data(request[bodyStart...].utf8)
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
            Task { @MainActor in
                self.lastError = error.localizedDescription
            }
            response = """
            HTTP/1.1 400 Bad Request\r
            Access-Control-Allow-Origin: *\r
            Content-Length: 0\r
            \r
            """
        }
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
