import Foundation
import SwiftUI
import Combine

// Historial de progreso (UserDefaults). En producción esto vive en el servidor.
final class HistoryStore: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    private let key = "swinglens_history"

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessions = arr
        }
    }
    func add(_ r: AnalysisResult) {
        let rec = SessionRecord(
            date: Date(), club: r.club, angle: r.angle, score: r.score,
            headStability: r.headStability, hipRotation: r.hipRotation, tempo: r.tempo,
            spineRet: r.shape?.spineRet.map { Int($0.rounded()) }, shape: r.shape?.shape
        )
        sessions.append(rec)
        while sessions.count > 60 { sessions.removeFirst() }
        if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: key) }
    }

    var best: Int { sessions.map { $0.score }.max() ?? 0 }
    var avg: Int { sessions.isEmpty ? 0 : Int(Double(sessions.map { $0.score }.reduce(0,+)) / Double(sessions.count)) }
    var last: Int { sessions.last?.score ?? 0 }
}

// Llama al backend (Cloudflare Worker) para el análisis de Birdie.
// Pon aquí la URL de tu worker. Soporta Claude o Gemini según configures el worker.
enum BirdieService {
    static let proxyURL = ""   // ej. "https://swinglens-birdie.TUCUENTA.workers.dev"

    struct Block: Encodable {
        let type: String
        let text: String?
        let source: Source?
        struct Source: Encodable { let type: String; let media_type: String; let data: String }
        init(text: String) { type = "text"; self.text = text; source = nil }
        init(imageBase64: String) { type = "image"; text = nil; source = Source(type: "base64", media_type: "image/jpeg", data: imageBase64) }
    }

    static func coach(prompt: String, images: [String]) async -> String {
        guard !proxyURL.isEmpty, let url = URL(string: proxyURL) else {
            return "Configura BirdieService.proxyURL con la URL de tu Cloudflare Worker para activar a Birdie."
        }
        var content: [Block] = [Block(text: prompt)]
        for img in images { content.append(Block(imageBase64: img)) }
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 900,
            "messages": [["role": "user", "content": content.map { encodeBlock($0) }]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return "Error armando la petición." }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        do {
            let (respData, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let contentArr = obj["content"] as? [[String: Any]] {
                return contentArr.compactMap { $0["text"] as? String }.joined()
            }
            return "Sin respuesta del modelo."
        } catch {
            return "Error de conexión: \(error.localizedDescription)"
        }
    }

    private static func encodeBlock(_ b: Block) -> [String: Any] {
        if b.type == "text" { return ["type": "text", "text": b.text ?? ""] }
        return ["type": "image", "source": ["type": "base64", "media_type": b.source?.media_type ?? "image/jpeg", "data": b.source?.data ?? ""]]
    }
}
