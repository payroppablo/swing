import Foundation
import CoreGraphics

// Bastón y ángulo de cámara
enum Club: String, Codable, CaseIterable, Identifiable {
    case driver, iron, wedge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .driver: return "Driver"
        case .iron:   return "Hierro"
        case .wedge:  return "Wedge"
        }
    }
    // Referencias ideales aproximadas (tempo, ventana de plano de manos en grados)
    var tempo: String { self == .driver ? "3.0:1" : self == .iron ? "2.9:1" : "2.6:1" }
    var planeLo: Int { self == .driver ? 38 : self == .iron ? 45 : 50 }
    var planeHi: Int { self == .driver ? 50 : self == .iron ? 58 : 64 }
}

enum CameraAngle: String, Codable { case dtl, faceOn
    var short: String { self == .dtl ? "DTL" : "Face-on" }
}

// Una muestra de frame: tiempo + keypoints (en coords de imagen, y hacia abajo)
struct FrameSample {
    let t: Double
    var points: [String: CGPoint]   // nombre -> punto
    var scores: [String: Double]    // nombre -> confianza
    var shoulderAngle: Double?
    var hipAngle: Double?
    var spineTilt: Double?
    var image: CGImage?             // para mostrar el checkpoint
}

// Los 4 checkpoints (índices dentro de la serie)
struct Checkpoints {
    var address: Int
    var top: Int
    var impact: Int
    var finish: Int
    var debug: String = ""
}

// Análisis de plano/postura
struct ShapeInfo: Codable {
    var planeAngle: Int?
    var pathDelta: Int?
    var pathLabel: String?
    var shape: String?
    var shapeNote: String?
    var spineAddr: Double?
    var spineRet: Double?
}

// Resultado completo de un análisis
struct AnalysisResult {
    var score: Int
    var headStability: Int
    var hipRotation: Int
    var tempo: Int
    var followThrough: Int
    var setup: Int
    var tempoRatio: String
    var hipDeg: Int
    var headMovCm: Double
    var club: Club
    var angle: CameraAngle
    var series: [FrameSample]
    var checkpoints: Checkpoints?
    var shape: ShapeInfo?
    var recordID: UUID? = nil   // id en el historial (para editar/reabrir)
}

// Registro guardado para el historial de progreso. Guarda lo suficiente para
// REABRIR el reporte completo (incluyendo las 4 fotos de checkpoints en JPEG).
struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var club: Club
    var angle: CameraAngle
    var score: Int
    var headStability: Int
    var hipRotation: Int
    var tempo: Int
    var followThrough: Int
    var setup: Int
    var tempoRatio: String
    var hipDeg: Int
    var headMovCm: Double
    var shape: ShapeInfo?
    var checkpointImages: [Data]   // address, top, impact, finish (jpeg)
}
