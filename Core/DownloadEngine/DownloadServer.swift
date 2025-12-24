import Foundation
import Network

class DownloadServer {
    static let shared = DownloadServer()
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8765
    private let queue = DispatchQueue(label: "com.optiload.server")
    
    private init() {}
    
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("🌐 Download server running on http://localhost:8765")
                case .failed(let error):
                    print("❌ Server failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.start(queue: queue)
        } catch {
            print("❌ Failed to start server: \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processRequest(data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        // Handle CORS preflight OPTIONS request
        if request.contains("OPTIONS /download") {
            sendCORSPreflightResponse(connection: connection)
            return
        }
        
        // Handle POST request
        guard request.contains("POST /download") else {
            sendResponse(connection: connection, statusCode: 404, body: "Not Found")
            return
        }
        
        // Extract JSON body from request
        if let bodyStart = request.range(of: "\r\n\r\n"),
           let jsonData = request[bodyStart.upperBound...].data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let urlString = json["url"] as? String,
           let url = URL(string: urlString) {
            
            let filename = json["filename"] as? String ?? url.lastPathComponent
            
            print("📥 Download request: \(filename)")
            print("🔗 URL: \(urlString)")
            
            // Add to download queue using Task for async context
            let urlCopy = url
            Task { @MainActor in
                try? await DownloadManager.shared.addDownload(url: urlCopy)
            }
            
            sendResponse(connection: connection, statusCode: 200, body: "{\"success\":true}")
        } else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
        }
    }
    
    private func sendCORSPreflightResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Content-Length: 0\r
        \r
        
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let response = """
        HTTP/1.1 \(statusCode) OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        \r
        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    func stop() {
        listener?.cancel()
        print("🛑 Download server stopped")
    }
}
