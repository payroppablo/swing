import Foundation

// Paso 1 del plan de ML: cada vez que el usuario CORRIGE un checkpoint a mano,
// guardamos una "etiqueta" (la pose de ese frame + qué checkpoint es). Con
// estas etiquetas verificadas por humanos luego entrenamos un modelo (Create
// ML) para detectar las fases mejor. Se guarda local; se exporta cuando quieras.
struct TrainingSample: Codable {
    var date: Date
    var club: String
    var angle: String
    var checkpoint: String          // address / top / impact / finish
    var t: Double                   // tiempo del frame en el video
    var rotation: Int
    var source: String              // "corrected" (verificado por el usuario)
    var keypoints: [String: [Double]]  // nombre -> [x, y, score]
}

final class TrainingStore {
    static let shared = TrainingStore()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("swinglens_training.jsonl")
    }
    var url: URL { fileURL }

    func add(_ s: TrainingSample) {
        guard let data = try? JSONEncoder().encode(s),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        guard let bytes = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path),
           let h = try? FileHandle(forWritingTo: fileURL) {
            h.seekToEndOfFile(); h.write(bytes); try? h.close()
        } else {
            try? bytes.write(to: fileURL)
        }
    }

    var count: Int {
        guard let s = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }
        return s.split(separator: "\n").count
    }
}
