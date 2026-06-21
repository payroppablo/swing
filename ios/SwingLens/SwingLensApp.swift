import SwiftUI
import Combine

@main
struct SwingLensApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state)
        }
    }
}

enum Screen { case home, upload, preview, analysis, results, progress, drills }

@MainActor
final class AppState: ObservableObject {
    @Published var screen: Screen = .home
    @Published var club: Club = .driver
    @Published var angle: CameraAngle = .dtl
    @Published var result: AnalysisResult?
    @Published var progress: Double = 0
    @Published var birdieText: String = ""
    @Published var birdieLoading = false
    @Published var resultsFrom: Screen = .upload   // a dónde vuelve el botón atrás
    @Published var pickedURL: URL?                 // video elegido (para previsualizar/recortar)
    @Published var trainingCount = TrainingStore.shared.count
    let history = HistoryStore()

    // Tras elegir video -> pantalla de vista previa y recorte
    func preparePreview(_ url: URL) {
        pickedURL = url
        screen = .preview
    }

    func analyze(url: URL, start: Double = 0, len: Double = 10) {
        screen = .analysis
        progress = 0
        let club = self.club, angle = self.angle
        Task.detached(priority: .userInitiated) {
            let res = await PoseAnalyzer.analyze(url: url, club: club, angle: angle, start: start, len: len) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run {
                if var res = res {
                    res.videoURL = url
                    let id = self.history.add(res)
                    res.recordID = id
                    self.result = res
                    self.birdieText = ""
                    self.resultsFrom = .home
                    self.saveAutoSamples(res)
                    self.screen = .results
                } else {
                    self.screen = .upload
                }
            }
        }
    }

    // Cambiar el bastón si te equivocaste (actualiza el reporte y el historial)
    func changeClub(_ c: Club) {
        guard var r = result else { return }
        r.club = c
        result = r
        if let id = r.recordID { history.updateClub(id, c) }
    }

    // Borrar una sesión del historial
    func deleteSession(_ id: UUID) {
        history.delete(id)
        objectWillChange.send()   // refresca la pantalla de progreso
    }

    // Reabrir un reporte guardado desde Progreso
    func openSession(_ rec: SessionRecord) {
        result = rec.toResult()
        birdieText = ""
        resultsFrom = .progress
        screen = .results
    }

    // Guarda las 4 posiciones auto-detectadas como muestras (source="auto")
    func saveAutoSamples(_ r: AnalysisResult) {
        guard let cp = r.checkpoints else { return }
        let map: [(String, Int)] = [("address", cp.address), ("top", cp.top), ("impact", cp.impact), ("finish", cp.finish)]
        for (label, idx) in map where r.series.indices.contains(idx) {
            let f = r.series[idx]
            var kp: [String: [Double]] = [:]
            for (name, p) in f.points { kp[name] = [Double(p.x), Double(p.y), f.scores[name] ?? 0] }
            if kp.count >= 6 {
                TrainingStore.shared.add(TrainingSample(
                    date: Date(), club: r.club.rawValue, angle: r.angle.rawValue,
                    checkpoint: label, t: f.t, rotation: r.rotation, source: "auto", keypoints: kp))
            }
        }
        trainingCount = TrainingStore.shared.count
    }

    // Ajuste manual de un checkpoint (desde el scrubber)
    func updateCheckpoint(_ which: String, index i: Int, image: CGImage?) {
        guard var r = result, var cp = r.checkpoints, r.series.indices.contains(i) else { return }
        switch which {
        case "address": cp.address = i
        case "top":     cp.top = i
        case "impact":  cp.impact = i
        default:        cp.finish = i
        }
        if let img = image { r.series[i].image = img }
        r.checkpoints = cp
        r.shape = PoseAnalyzer.analyzeShape(r.series, checkpoints: cp)
        result = r
        if let id = r.recordID { history.updateCheckpoints(id, r) }

        // Paso 1 ML: guardar la corrección como dato de entrenamiento etiquetado
        let f = r.series[i]
        var kp: [String: [Double]] = [:]
        for (name, p) in f.points { kp[name] = [Double(p.x), Double(p.y), f.scores[name] ?? 0] }
        if !kp.isEmpty {
            TrainingStore.shared.add(TrainingSample(
                date: Date(), club: r.club.rawValue, angle: r.angle.rawValue,
                checkpoint: which, t: f.t, rotation: r.rotation, source: "corrected", keypoints: kp))
            trainingCount = TrainingStore.shared.count
        }
    }
}
