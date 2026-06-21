import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import CoreTransferable

// Carga el video elegido a un archivo temporal (AVAsset necesita URL)
struct Movie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}

// ── RESULTS ──
struct ResultsView: View {
    @EnvironmentObject var s: AppState
    @State private var showScrub = false
    @State private var ringProgress: CGFloat = 0
    @State private var selectedCP = "top"
    var r: AnalysisResult? { s.result }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    backRow { s.screen = s.resultsFrom }
                    if let r = r {
                        Menu {
                            ForEach(Club.allCases) { c in
                                Button { s.changeClub(c) } label: {
                                    Label(c.label, systemImage: r.club == c ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(r.club.label) · \(r.angle.short)")
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                            }
                            .font(.system(size: 10.5, weight: .bold)).foregroundColor(Theme.darkGreen)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: 0xEAF6EC)).cornerRadius(99)
                        }
                    }
                }
                if let r = r, !r.validSwing {
                    noSwingCard(r)
                } else if let r = r {
                    scoreHero(r)
                    comparisonStrip(r)
                    checkpointsRow(r)
                    if r.videoURL != nil {
                        Button { showScrub = true } label: {
                            HStack { Image(systemName: "slider.horizontal.3"); Text("Ajustar Top / Impacto…") }
                                .font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.darkGreen)
                                .frame(maxWidth: .infinity).padding(11)
                                .background(Color(hex: 0xEAF6EC)).cornerRadius(12)
                        }
                    }
                    tourCard(r)
                    if let seq = r.sequence { sequenceCard(seq) }
                    planePathCard(r)
                    if let shape = r.shape { postureCard(shape) }
                    metricsCard(r)
                    coachContent(r)
                    birdieSection(r)
                    Button { s.screen = .home } label: {
                        Text("Analizar otro swing").font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: 0x08311C)).frame(maxWidth: .infinity).padding(17)
                            .background(Theme.actionGreen).cornerRadius(15)
                    }
                } else {
                    Text("Sin análisis todavía").foregroundColor(Theme.slate).padding(.top, 60)
                }
            }
            .padding(20).padding(.top, 30)
        }
        .background(Theme.cream.ignoresSafeArea())
        .sheet(isPresented: $showScrub) { ScrubView() }
    }

    func verdict(_ score: Int) -> String {
        score >= 85 ? "Excelente — fundamentos de nivel tour." :
        score >= 70 ? "Sólido — con mejoras claras por delante." :
        score >= 50 ? "En desarrollo — enfócate en lo básico." :
                      "A trabajar — empieza por tu setup."
    }

    func noSwingCard(_ r: AnalysisResult) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(Theme.amber).padding(.top, 40)
            Text("No detectamos un swing claro").font(Theme.serif(24)).foregroundColor(Theme.ink).multilineTextAlignment(.center)
            Text("Pose detectada: \(r.detectedFrames)/\(r.totalFrames) frames. No analizamos para no darte datos inventados.")
                .font(.system(size: 13)).foregroundColor(Theme.slate).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                tipRow("Graba al golfista de cuerpo completo (pies a cabeza)")
                tipRow("Cámara fija y buena luz (evita el contraluz fuerte)")
                tipRow("Que el tramo cubra del address al finish")
            }
            .padding(14).swCard().padding(.top, 6)
            Button { s.screen = .upload } label: {
                Text("Probar otro video").font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: 0x08311C)).frame(maxWidth: .infinity).padding(17)
                    .background(Theme.actionGreen).cornerRadius(15)
            }.padding(.top, 8)
        }
    }
    func tipRow(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.actionGreen).font(.system(size: 15))
            Text(t).font(.system(size: 13)).foregroundColor(Theme.slate)
            Spacer(minLength: 0)
        }
    }

    func scoreHero(_ r: AnalysisResult) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(hex: 0xEAEDE5), lineWidth: 13).frame(width: 160, height: 160)
                Circle().trim(from: 0, to: ringProgress)
                    .stroke(LinearGradient(colors: [Theme.actionGreen, Theme.lightGreen], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .frame(width: 160, height: 160).rotationEffect(.degrees(-90))
                    .shadow(color: Theme.actionGreen.opacity(0.35), radius: 8)
                VStack(spacing: 0) {
                    Text("\(r.score)").font(Theme.serif(54)).foregroundColor(Theme.ink)
                    Text("SWING SCORE").font(.system(size: 9, weight: .medium)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C))
                }
            }
            Text(verdict(r.score)).font(.system(size: 16, design: .serif)).italic()
                .foregroundColor(Color(hex: 0x3C463F)).multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            ringProgress = 0
            withAnimation(.easeOut(duration: 1.1)) { ringProgress = CGFloat(r.score) / 100 }
        }
    }

    // Comparación contra tu historial (mejor / promedio)
    @ViewBuilder
    func comparisonStrip(_ r: AnalysisResult) -> some View {
        let best = s.history.best
        let avg = s.history.avg
        let isRecord = best > 0 && r.score >= best && s.history.sessions.count > 1
        HStack(spacing: 10) {
            if isRecord {
                Label("¡Nuevo récord!", systemImage: "trophy.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: 0x8A6B2E))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(Color(hex: 0xF7F0DE)).cornerRadius(12)
            } else if best > 0 {
                miniStat("Tu mejor", "\(best)")
                miniStat("Promedio", "\(avg)")
            }
        }
    }
    func miniStat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundColor(Theme.slate)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.darkGreen)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(Color.white).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder))
    }

    // El "plus": secuencia cinemática (orden de la bajada)
    func sequenceCard(_ seq: SequenceInfo) -> some View {
        let chipColor = seq.correct ? Theme.actionGreen : Theme.amber
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SECUENCIA CINEMÁTICA").font(.system(size: 11, weight: .semibold)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
                Spacer()
                Text(seq.correct ? "✓ Buen orden" : "⚠ Revisar").font(.system(size: 10.5, weight: .bold)).foregroundColor(chipColor)
            }
            HStack(spacing: 6) {
                ForEach(Array(seq.order.enumerated()), id: \.offset) { i, name in
                    Text(name).font(.system(size: 12.5, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(i == 0 ? Theme.darkGreen : (i == 1 ? Color(hex: 0x3E8F58) : Theme.actionGreen)).cornerRadius(10)
                    if i < seq.order.count - 1 {
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: 0xB3BBB4))
                    }
                }
            }
            Text(seq.correct
                 ? "Tus caderas lideran, luego el torso y al final los brazos — así se genera y libera la potencia (efecto látigo). Eso es secuencia de tour."
                 : "Tus brazos/hombros se adelantan a las caderas, lo que fuga potencia. Haz el drill Pump-and-Hold para que las caderas lideren la bajada.")
                .font(.system(size: 12.5)).foregroundColor(Theme.slate).fixedSize(horizontal: false, vertical: true)
            Text("Ideal: Caderas → Hombros → Brazos")
                .font(Theme.mono(10)).foregroundColor(Color(hex: 0xB3BBB4))
        }
        .padding(16).background(Color.white).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // ── Comparación vs swing de tour (v1: contra estándar ideal por bastón) ──
    struct MatchRow: Identifiable { let id = UUID(); let name: String; let your: String; let ideal: String; let score: Int }

    func clamp(_ v: Double) -> Int { Int(max(0, min(100, v))) }

    func tourMatch(_ r: AnalysisResult) -> (overall: Int, rows: [MatchRow]) {
        var rows: [MatchRow] = []

        // Tempo (ideal 3.0:1)
        let ratio = Double(r.tempoRatio.split(separator: ":").first.map(String.init) ?? "") ?? 3.0
        let tempoScore = clamp(100 - abs(ratio - 3.0) * 30)
        rows.append(MatchRow(name: "Tempo", your: r.tempoRatio, ideal: "3.0:1", score: tempoScore))

        // Secuencia
        if let seq = r.sequence {
            rows.append(MatchRow(name: "Secuencia", your: seq.correct ? "Correcta" : "Invertida",
                                 ideal: "Caderas→Brazos", score: seq.correct ? 100 : 45))
        }
        // Plano de manos (ventana por bastón)
        if let pa = r.shape?.planeAngle {
            let lo = Double(r.club.planeLo), hi = Double(r.club.planeHi)
            let s: Double = (Double(pa) >= lo && Double(pa) <= hi) ? 100 :
                100 - min(Double(pa) - hi, lo - Double(pa)).magnitude * 4
            rows.append(MatchRow(name: "Plano manos", your: "\(pa)°", ideal: "\(r.club.planeLo)–\(r.club.planeHi)°", score: clamp(s)))
        }
        // Postura (cambio de spine address→impacto; menos es mejor)
        if let ret = r.shape?.spineRet {
            rows.append(MatchRow(name: "Postura", your: "±\(Int(ret.rounded()))°", ideal: "≤8°", score: clamp(100 - max(0, ret - 6) * 5.5)))
        }
        // Cabeza (cm)
        rows.append(MatchRow(name: "Cabeza", your: "\(r.headMovCm) cm", ideal: "≤2 cm", score: clamp(100 - max(0, r.headMovCm - 1.5) * 16)))

        // X-Factor (separación hombros-caderas en el Top)
        if let cp = r.checkpoints {
            let A = r.series[cp.address], T = r.series[cp.top]
            if let sa = A.shoulderAngle, let ta = T.shoulderAngle, let ha = A.hipAngle, let th = T.hipAngle {
                let xf = PoseAnalyzer.angleDiff(ta, sa) - PoseAnalyzer.angleDiff(th, ha)
                let s: Double = (xf >= 20 && xf <= 45) ? 100 : 100 - (xf < 20 ? (20 - xf) : (xf - 45)) * 3
                rows.append(MatchRow(name: "X-Factor", your: "\(Int(xf.rounded()))°", ideal: "20–45°", score: clamp(s)))
            }
        }

        let overall = rows.isEmpty ? 0 : Int((rows.map { Double($0.score) }.reduce(0, +) / Double(rows.count)).rounded())
        return (overall, rows)
    }

    func tourCard(_ r: AnalysisResult) -> some View {
        let m = tourMatch(r)
        let col = m.overall >= 75 ? Theme.actionGreen : (m.overall >= 55 ? Theme.amber : Color(hex: 0xC2843B))
        let yourImg = r.checkpoints.flatMap { r.series[$0.impact].image }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TÚ vs TOUR").font(.system(size: 11, weight: .semibold)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
                Spacer()
                Text("\(r.club.label)").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.darkGreen)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(Color(hex: 0xEAF6EC)).cornerRadius(99)
            }

            // Paneles lado a lado: TÚ vs TOUR
            HStack(spacing: 10) {
                // TÚ
                VStack(spacing: 6) {
                    ZStack {
                        if let cg = yourImg {
                            Image(uiImage: UIImage(cgImage: cg)).resizable().scaledToFill()
                        } else {
                            Rectangle().fill(Color(hex: 0x0D241C))
                        }
                    }
                    .frame(height: 150).frame(maxWidth: .infinity).clipped().cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.actionGreen, lineWidth: 2))
                    .overlay(alignment: .topLeading) {
                        Text("TÚ").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.actionGreen).cornerRadius(8).padding(6)
                    }
                    Text("Impacto").font(.system(size: 10)).foregroundColor(Theme.slate)
                }
                // TOUR (referencia ideal)
                VStack(spacing: 6) {
                    ZStack {
                        LinearGradient(colors: [Theme.darkGreen, Color(hex: 0x0D241C)], startPoint: .top, endPoint: .bottom)
                        VStack(spacing: 8) {
                            Image(systemName: "figure.golf").font(.system(size: 40)).foregroundColor(Theme.lightGreen)
                            Text("Estándar de tour").font(.system(size: 10)).foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(height: 150).frame(maxWidth: .infinity).clipped().cornerRadius(12)
                    .overlay(alignment: .topLeading) {
                        Text("TOUR").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: 0x08311C))
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.lightGreen).cornerRadius(8).padding(6)
                    }
                    Text("Referencia").font(.system(size: 10)).foregroundColor(Theme.slate)
                }
            }

            // Match global
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color(hex: 0xEAEDE5), lineWidth: 9).frame(width: 72, height: 72)
                    Circle().trim(from: 0, to: CGFloat(m.overall) / 100)
                        .stroke(col, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Text("\(m.overall)").font(Theme.serif(24)).foregroundColor(Theme.ink)
                        Text("%").font(.system(size: 9)).foregroundColor(Theme.slate)
                    }
                }
                Text(m.overall >= 75 ? "Muy cerca de un swing de tour. Pule los detalles."
                     : m.overall >= 55 ? "Buen camino. Hay 2-3 cosas que te separan del nivel tour."
                     : "Tienes margen claro. Enfócate en lo rojo de abajo y verás saltos rápidos.")
                    .font(.system(size: 13)).foregroundColor(Theme.slate).fixedSize(horizontal: false, vertical: true)
            }

            // Barras por métrica (tú vs tour)
            VStack(spacing: 9) {
                ForEach(m.rows) { row in
                    VStack(spacing: 4) {
                        HStack {
                            Text(row.name).font(.system(size: 12.5, weight: .medium)).foregroundColor(Color(hex: 0x3C463F))
                            Spacer()
                            Text("tú \(row.your)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.darkGreen)
                            Text("· tour \(row.ideal)").font(.system(size: 11)).foregroundColor(Color(hex: 0xB3BBB4))
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: 0xEEF1EA)).frame(height: 6)
                                Capsule().fill(row.score >= 75 ? Theme.actionGreen : (row.score >= 55 ? Theme.amber : Color(hex: 0xC2843B)))
                                    .frame(width: g.size.width * CGFloat(row.score) / 100, height: 6)
                            }
                        }.frame(height: 6)
                    }
                }
            }
        }
        .padding(16).background(Color.white).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    func checkpointsRow(_ r: AnalysisResult) -> some View {
        let labels = ["Address", "Top", "Impacto", "Finish"]
        let colors: [Color] = [Color(hex: 0x6B756F), Theme.amber, Theme.actionGreen, Color(hex: 0x6B756F)]
        let idxs: [Int] = r.checkpoints.map { [$0.address, $0.top, $0.impact, $0.finish] } ?? []
        let detRatio = r.totalFrames > 0 ? Double(r.detectedFrames) / Double(r.totalFrames) : 0
        let detColor = detRatio >= 0.6 ? Color(hex: 0x3E8F58) : (detRatio >= 0.3 ? Theme.amber : Color(hex: 0xC2843B))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SWING CHECKPOINTS").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C))
                Spacer()
                Text("pose \(r.detectedFrames)/\(r.totalFrames) · \(AppInfo.build)").font(Theme.mono(9)).foregroundColor(detColor)
            }
            if r.totalFrames > 0 && detRatio < 0.3 {
                Text("⚠ Casi no se detectó el cuerpo en este video. Graba al golfista de cuerpo completo, bien iluminado y ocupando buena parte del cuadro.")
                    .font(.system(size: 11.5)).foregroundColor(Color(hex: 0xC2843B)).fixedSize(horizontal: false, vertical: true)
            }
            let keys = ["address", "top", "impact", "finish"]
            HStack(spacing: 7) {
                ForEach(0..<idxs.count, id: \.self) { i in
                    Button { selectedCP = keys[i] } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                if let cg = r.series[idxs[i]].image {
                                    Image(uiImage: UIImage(cgImage: cg)).resizable().scaledToFill()
                                        .frame(height: 116).frame(maxWidth: .infinity).clipped()
                                } else {
                                    Rectangle().fill(Color(hex: 0x0D241C)).frame(height: 116)
                                }
                            }
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedCP == keys[i] ? Theme.darkGreen : colors[i],
                                        lineWidth: selectedCP == keys[i] ? 3 : (i == 1 || i == 2 ? 2 : 1)))
                            Text(labels[i]).font(.system(size: 9.5, weight: selectedCP == keys[i] || i == 1 || i == 2 ? .bold : .semibold))
                                .foregroundColor(selectedCP == keys[i] ? Theme.darkGreen : colors[i])
                        }
                    }
                }
            }
            // Recomendación del checkpoint seleccionado
            let adv = checkpointAdvice(selectedCP, r)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: adv.good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(adv.good ? Theme.actionGreen : Theme.amber).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(adv.title).font(.system(size: 13.5, weight: .bold)).foregroundColor(Theme.ink)
                    Text(adv.text).font(.system(size: 12.5)).foregroundColor(Theme.slate).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12).background(Color.white).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder))
        }
    }

    // Recomendación específica por checkpoint, basada en lo medido
    func checkpointAdvice(_ key: String, _ r: AnalysisResult) -> (title: String, text: String, good: Bool) {
        switch key {
        case "address":
            if r.setup >= 70 { return ("Address sólido", "Buena postura y hombros equilibrados al inicio. Mantén ese setup.", true) }
            return ("Mejora el address", "Inclínate desde la cadera con la espalda recta y nivela los hombros. Un buen setup arregla medio swing.", false)
        case "top":
            if r.headMovCm > 5 {
                return ("Cabeza en el Top", "Subiste/moviste la cabeza ~\(r.headMovCm) cm en el backswing. Mantenla quieta para contactar centrado. Drill: cabeza contra la pared.", false)
            }
            if let xf = topXFactor(r), xf < 18 {
                return ("Falta separación", "Poca separación hombros-cadera (~\(Int(xf))°) en el Top. Gira más el torso sobre caderas estables para crear X-factor.", false)
            }
            return ("Buen Top", "Giro completo y cabeza estable. Esa es la base de la potencia.", true)
        case "impact":
            if let ret = r.shape?.spineRet, ret > 12 {
                return ("Perdiste postura", "En el impacto te estiraste/levantaste (early extension, ±\(Int(ret))°). Mantén el ángulo de columna. Drill: sentarse al impacto.", false)
            }
            if r.hipRotation < 55 {
                return ("Abre la cadera", "Tu cadera no abre lo suficiente al impacto, fugas potencia. Drill: Pump-and-Hold para que la cadera lidere.", false)
            }
            return ("Buen impacto", "Mantienes postura y la cadera abre hacia el objetivo. Así se libera la potencia.", true)
        default:
            if r.followThrough >= 70 { return ("Finish balanceado", "Terminas con el peso en el pie delantero y el pecho al objetivo. ", true) }
            return ("Sostén el finish", "Terminas algo desbalanceado. Llega a un finish completo y aguántalo 3 segundos.", false)
        }
    }

    func topXFactor(_ r: AnalysisResult) -> Double? {
        guard let cp = r.checkpoints else { return nil }
        let A = r.series[cp.address], T = r.series[cp.top]
        guard let sa = A.shoulderAngle, let ta = T.shoulderAngle, let ha = A.hipAngle, let th = T.hipAngle else { return nil }
        return PoseAnalyzer.angleDiff(ta, sa) - PoseAnalyzer.angleDiff(th, ha)
    }

    // Forma del golpe + plano: foto con tu trayectoria + tendencia + ver swing
    func planePathCard(_ r: AnalysisResult) -> some View {
        let shape = r.shape
        let pathColor: Color = (shape?.pathDelta ?? 0) > 8 || (shape?.pathDelta ?? 0) < -8 ? Theme.amber : Theme.actionGreen
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FORMA DEL GOLPE · PLANO").font(.system(size: 11, weight: .semibold)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
                Spacer()
                Text("ESTIMADO").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: 0x9A8458))
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Color(hex: 0xF5EFE0)).cornerRadius(99)
            }
            if let label = shape?.pathLabel {
                Text(label).font(.system(size: 17, weight: .bold)).foregroundColor(pathColor)
                Text("\(shape?.shape ?? "") — \(shape?.shapeNote ?? "")").font(.system(size: 12.5)).foregroundColor(Theme.slate)
            }
            // Foto del finish con tu trayectoria dibujada sobre el golfista
            if let cp = r.checkpoints, let cg = r.series[cp.finish].image {
                Image(uiImage: UIImage(cgImage: cg)).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(maxHeight: 320).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder))
            }
            // Leyenda de colores de la trayectoria dibujada en la foto
            HStack(spacing: 14) {
                legendDot(Theme.lightGreen, "Backswing")
                legendDot(Theme.amber, "Bajada")
                Spacer()
            }
            // Barra para ver/arrastrar el swing cuadro por cuadro
            if r.videoURL != nil {
                Button { showScrub = true } label: {
                    HStack { Image(systemName: "play.rectangle.on.rectangle"); Text("Ver el swing cuadro por cuadro") }
                        .font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.darkGreen)
                        .frame(maxWidth: .infinity).padding(11)
                        .background(Color(hex: 0xEAF6EC)).cornerRadius(12)
                }
            }
            HStack(spacing: 10) {
                stat(shape?.planeAngle.map { "\($0)°" } ?? "—", "Tu plano", "ideal \(r.club.planeLo)–\(r.club.planeHi)°")
                stat("\(r.tempoRatio)", "Tempo", "ideal 3.0:1")
            }
            Text("Vision no ve el palo: la trayectoria se estima de las manos y la forma es tendencia (no mide la cara del palo).")
                .font(.system(size: 10.5)).foregroundColor(Color(hex: 0x9AA39C))
        }
        .padding(16).background(Color.white).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 9, height: 9)
            Text(t).font(.system(size: 10.5)).foregroundColor(Theme.slate)
        }
    }

    // Postura (spine) como tarjeta aparte
    func postureCard(_ shape: ShapeInfo) -> some View {
        let retCol = (shape.spineRet ?? 0) > 12 ? Theme.amber : Theme.actionGreen
        return VStack(alignment: .leading, spacing: 10) {
            Text("POSTURA (SPINE ANGLE)").font(.system(size: 11, weight: .semibold)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
            HStack(spacing: 10) {
                stat(shape.spineAddr.map { "\(Int($0.rounded()))°" } ?? "—", "Address", "inclinación")
                stat(shape.spineRet.map { "±\(Int($0.rounded()))°" } ?? "—", "Cambio", "address→impacto")
            }
            Text((shape.spineRet ?? 0) > 12
                 ? "Pierdes postura entre el address y el impacto (early extension). Mantén el ángulo de columna para contacto y consistencia."
                 : "Buena retención de postura: mantienes el ángulo de columna del address al impacto.")
                .font(.system(size: 12.5)).foregroundColor(retCol == Theme.amber ? Color(hex: 0x8A6B2E) : Theme.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).swCard()
    }

    func stat(_ big: String, _ label: String, _ sub: String) -> some View {
        VStack(spacing: 2) {
            Text(big).font(Theme.serif(20)).foregroundColor(Theme.ink)
            Text(label.uppercased()).font(.system(size: 9)).foregroundColor(Color(hex: 0x9AA39C))
            Text(sub).font(.system(size: 8.5)).foregroundColor(Color(hex: 0xB3BBB4))
        }
        .frame(maxWidth: .infinity).padding(11).background(Theme.cream).cornerRadius(12)
    }

    func metricsCard(_ r: AnalysisResult) -> some View {
        VStack(spacing: 0) {
            row("Tempo", r.tempo, "\(r.tempoRatio)")
            row("Estabilidad cabeza", r.headStability, "\(r.headMovCm) cm")
            row("Rotación cadera", r.hipRotation, "\(r.hipDeg)°")
            row("Follow-through", r.followThrough, nil)
            row("Setup", r.setup, nil)
        }
        .padding(.vertical, 4).swCard(14)
    }
    func row(_ name: String, _ score: Int, _ extra: String?) -> some View {
        HStack {
            Text(name).font(.system(size: 13)).foregroundColor(Theme.slate)
            Spacer()
            if let e = extra { Text(e).font(Theme.mono(11)).foregroundColor(Color(hex: 0x9AA39C)) }
            Text("\(score)").font(.system(size: 14, weight: .bold))
                .foregroundColor(score >= 70 ? Color(hex: 0x3E8F58) : Theme.amber)
                .frame(width: 34, alignment: .trailing)
        }.padding(.horizontal, 12).padding(.vertical, 9)
    }

    // Tips (fortalezas / focus) + drill, generados de las métricas reales
    struct Finding { let key: String; let score: Int; let label: String
        let sTitle: String; let sDesc: String; let fTitle: String; let fDesc: String }

    func findings(_ r: AnalysisResult) -> [Finding] {
        var list: [Finding] = [
            Finding(key: "tempo", score: r.tempo, label: "tempo",
                sTitle: "Tempo suave y repetible", sDesc: "Tu ratio \(r.tempoRatio) está cerca del estándar 3:1.",
                fTitle: "Tempo por pulir", fDesc: "Tu ratio \(r.tempoRatio) se aleja del 3:1; la transición va apurada."),
            Finding(key: "setup", score: r.setup, label: "setup",
                sTitle: "Buen setup y alineación", sDesc: "Postura y hombros nivelados en el address.",
                fTitle: "Setup desbalanceado", fDesc: "Los hombros se ven inclinados en el address; nivélalos."),
            Finding(key: "head", score: r.headStability, label: "cabeza",
                sTitle: "Cabeza estable al impacto", sDesc: "Tu cabeza se mantiene en ~\(r.headMovCm) cm.",
                fTitle: "Estabilidad de cabeza", fDesc: "Tu cabeza se desplaza ~\(r.headMovCm) cm hacia el objetivo."),
            Finding(key: "hip", score: r.hipRotation, label: "cadera",
                sTitle: "Buena rotación de cadera", sDesc: "Unos \(r.hipDeg)° de giro: buena fuente de potencia.",
                fTitle: "Rotación de cadera limitada", fDesc: "Solo ~\(r.hipDeg)° de giro; pierdes potencia y lag."),
            Finding(key: "ft", score: r.followThrough, label: "finish",
                sTitle: "Finish balanceado", sDesc: "Mantienes una terminación consistente.",
                fTitle: "Follow-through inconsistente", fDesc: "La terminación varía; trabaja en sostenerla."),
        ]
        // Postura / early extension: si te levantas o agachas entre address e impacto
        if let ret = r.shape?.spineRet {
            let pScore = clamp(100 - max(0, ret - 6) * 5.5)
            list.append(Finding(key: "posture", score: pScore, label: "postura",
                sTitle: "Mantienes la postura", sDesc: "Conservas el ángulo de columna (±\(Int(ret))°).",
                fTitle: "Pierdes la postura", fDesc: "Cambias ~\(Int(ret))° tu ángulo de columna entre address e impacto (te levantas o te agachas); afecta el contacto."))
        }
        return list
    }

    func drillFor(_ key: String) -> (String, String, String) {
        switch key {
        case "tempo":  return ("Cuenta 1-2-3", "Cuenta \"1-2\" subiendo y \"3\" bajando para grabar un ritmo 3:1.", "3 series · 10 swings · 5 min")
        case "setup":  return ("Chequeo al espejo", "Frente a un espejo, iguala columna neutra y hombros nivelados antes de cada repe.", "2 series · 8 reps · 4 min")
        case "head":   return ("Cabeza contra la pared", "En address apoya la cabeza en la pared y mantén el contacto en el backswing.", "3 series · 10 reps · 6 min")
        case "hip":    return ("Pump-and-Hold", "Pausa a mitad de bajada y sostén para grabar la secuencia de cadera antes del release.", "3 series · 10 reps · 5 min")
        case "posture": return ("Glúteo a la pared", "Con los glúteos tocando una pared/silla, haz el swing manteniendo el contacto; impide que te levantes.", "3 series · 10 reps · 6 min")
        default:        return ("Sostén el Finish", "Llega a un finish completo y sostén 3 segundos balanceado en el lado líder.", "3 series · 8 reps · 5 min")
        }
    }

    // Qué hacer (acción concreta) por área
    func fixFor(_ key: String) -> String {
        switch key {
        case "tempo":  return "No aceleres desde arriba: empieza la bajada lento y deja que la velocidad llegue al pasar por la bola."
        case "setup":  return "Inclínate desde la cadera (no encorves la espalda), rodillas suaves y peso en el centro del pie."
        case "head":   return "Fija la vista en la bola y mantén la cabeza detrás de ella hasta DESPUÉS del impacto."
        case "hip":    return "Inicia la bajada abriendo la cadera delantera hacia el objetivo ANTES de soltar los brazos."
        case "posture": return "Mantén la inclinación desde la cadera del address hasta el impacto: no te endereces ni te hundas."
        default:        return "Gira a un finish completo: pecho al objetivo, peso en el pie delantero, y sostenlo 3 segundos."
        }
    }
    // Título "subir de nivel" cuando el área ya va bien
    func nextLevelTitle(_ key: String) -> String {
        switch key {
        case "tempo":  return "afina aún más tu ritmo"
        case "setup":  return "perfecciona tu setup"
        case "head":   return "más quietud de cabeza"
        case "hip":    return "abre más la cadera"
        case "posture": return "mantén aún mejor la postura"
        default:        return "un finish más completo"
        }
    }
    // Cómo sentirlo
    func feelFor(_ key: String) -> String {
        switch key {
        case "tempo":  return "Siente que el palo 'cae' suave al iniciar la bajada y la potencia aparece sola en el impacto."
        case "setup":  return "Espalda recta y libre para girar; brazos colgando justo bajo los hombros."
        case "head":   return "Como si giraras alrededor de un poste fijo que pasa por tu cabeza."
        case "hip":    return "La cadera 'arranca' primero y los brazos llegan después — efecto látigo."
        case "posture": return "Siente los botones de la camisa apuntando a la bola todo el tiempo; la cabeza no sube."
        default:        return "Termina en equilibrio, como una foto que puedas aguantar sin tambalearte."
        }
    }

    @ViewBuilder
    func coachContent(_ r: AnalysisResult) -> some View {
        let all = findings(r)
        let strengths = Array(all.filter { $0.score >= 70 }.sorted { $0.score > $1.score }.prefix(3))
        let focusRaw = all.filter { $0.score < 70 }.sorted { $0.score < $1.score }
        let focus = Array((focusRaw.isEmpty ? [all.min { $0.score < $1.score }!] : focusRaw).prefix(3))
        let strengthsShown = strengths.isEmpty ? [all.max { $0.score < $1.score }!] : strengths

        VStack(alignment: .leading, spacing: 11) {
            Text("LO QUE HACES BIEN").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x3E8F58))
            ForEach(strengthsShown, id: \.key) { f in
                tipCard(icon: "checkmark.circle.fill", iconColor: Color(hex: 0x3E8F58),
                        title: f.sTitle, desc: f.sDesc, badge: "Fortaleza", badgeColor: Color(hex: 0x3E8F58),
                        score: f.score, scoreLabel: f.label, light: true)
            }

            // TU ARREGLO #1 — lo más importante, accionable
            if let top = focus.first { arregloCard(top) }

            // Otras áreas a mejorar (con qué hacer)
            if focus.count > 1 {
                Text("OTRAS ÁREAS").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C)).padding(.top, 4)
                ForEach(Array(focus.dropFirst()), id: \.key) { f in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(f.fTitle).font(.system(size: 14.5, weight: .semibold)).foregroundColor(Theme.ink)
                            Spacer()
                            Text("\(f.score)").font(Theme.serif(18)).foregroundColor(Theme.amber)
                        }
                        Text("👉 Qué hacer: \(fixFor(f.key))").font(.system(size: 12.5)).foregroundColor(Theme.slate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).background(Color.white).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder))
                }
            }

            Button { s.screen = .drills } label: {
                HStack { Image(systemName: "list.bullet.rectangle"); Text("Ver todos los ejercicios") }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.darkGreen)
                    .frame(maxWidth: .infinity).padding(13)
                    .background(Color(hex: 0xEAF6EC)).cornerRadius(13)
            }
        }
    }

    // Tarjeta destacada: arreglo principal, o "siguiente nivel" si ya vas bien
    func arregloCard(_ f: Finding) -> some View {
        let drill = drillFor(f.key)
        let isGood = f.score >= 70   // ya estás bien -> enfoque "subir de nivel"
        let header = isGood ? "TU SIGUIENTE NIVEL" : "TU ARREGLO #1"
        let title = isGood ? "Para exprimir más: \(nextLevelTitle(f.key))" : f.fTitle
        let problem = isGood
            ? "Ya lo haces bien (\(f.score)). Aun así, aquí es donde más puedes ganar para acercarte al nivel tour."
            : f.fDesc
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(header).font(.system(size: 11, weight: .bold)).tracking(2).foregroundColor(Theme.lightGreen)
                Spacer()
                Text("\(f.score)").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
            Text(title).font(Theme.serif(22)).foregroundColor(.white)
            blockLabel(isGood ? "DÓNDE GANAR MÁS" : "EL PROBLEMA", problem)
            blockLabel("QUÉ HACER", fixFor(f.key), strong: true)
            blockLabel("CÓMO SENTIRLO", feelFor(f.key))
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional").foregroundColor(Color(hex: 0x08311C))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Drill: \(drill.0)").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: 0x08311C))
                    Text(drill.2).font(.system(size: 10.5)).foregroundColor(Color(hex: 0x08311C).opacity(0.7))
                }
                Spacer()
            }
            .padding(11).background(Theme.lightGreen).cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(LinearGradient(colors: [Theme.darkGreen, Color(hex: 0x10301F)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Theme.darkGreen.opacity(0.25), radius: 10, y: 5)
    }

    func blockLabel(_ tag: String, _ text: String, strong: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tag).font(.system(size: 9.5, weight: .bold)).tracking(1).foregroundColor(Theme.lightGreen)
            Text(text).font(.system(size: strong ? 14 : 13, weight: strong ? .semibold : .regular))
                .foregroundColor(strong ? .white : Color(hex: 0xD8E8DB)).fixedSize(horizontal: false, vertical: true)
        }
    }

    func tipCard(icon: String, iconColor: Color, title: String, desc: String,
                 badge: String, badgeColor: Color, score: Int, scoreLabel: String, light: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 20))
                .frame(width: 44, height: 44).background(light ? Color(hex: 0xEAF6EC) : Theme.darkGreen).cornerRadius(13)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.ink)
                Text(desc).font(.system(size: 13)).foregroundColor(Theme.slate)
                HStack(spacing: 6) {
                    Circle().fill(badgeColor).frame(width: 7, height: 7)
                    Text(badge).font(.system(size: 11.5, weight: .semibold)).foregroundColor(badgeColor)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("\(score)").font(Theme.serif(22)).foregroundColor(light ? Color(hex: 0x3E8F58) : Theme.darkGreen)
                Text(scoreLabel.uppercased()).font(.system(size: 9)).foregroundColor(Color(hex: 0xB3BBB4))
            }
        }
        .padding(15).background(Color.white).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
    }

    func birdieSection(_ r: AnalysisResult) -> some View {
        VStack(spacing: 10) {
            if !s.birdieText.isEmpty {
                Text(s.birdieText).font(.system(size: 13)).foregroundColor(Color(hex: 0x3C463F))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(Theme.cream).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder))
            }
            Button { runBirdie(r) } label: {
                HStack { Image(systemName: "bubble.left.fill"); Text(s.birdieLoading ? "Analizando…" : "Birdie's deep analysis") }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.lightGreen)
                    .frame(maxWidth: .infinity).padding(15)
                    .background(Theme.darkGreen).cornerRadius(15)
            }.disabled(s.birdieLoading)
            Text("Análisis AI cuadro por cuadro · 1 gratis, luego Pro")
                .font(.system(size: 10.5)).foregroundColor(Color(hex: 0x9AA39C))
        }
    }

    func runBirdie(_ r: AnalysisResult) {
        s.birdieLoading = true
        let idxs = r.checkpoints.map { [$0.address, $0.top, $0.impact, $0.finish] } ?? []
        var images: [String] = []
        for i in idxs {
            if let cg = r.series[i].image, let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.6) {
                images.append(data.base64EncodedString())
            }
        }
        let prompt = """
        Eres Birdie, instructor de golf PGA, revisando un swing (\(r.angle.short)) con \(r.club.label).
        Score \(r.score). Tempo \(r.tempoRatio). Plano de manos \(r.shape?.planeAngle.map { "\($0)°" } ?? "n/d"), \
        path \(r.shape?.pathLabel ?? "n/d") (\(r.shape?.shape ?? "n/d")), cambio de postura \(r.shape?.spineRet.map { "±\(Int($0))°" } ?? "n/d").
        Aquí van Address, Top, Impacto y Finish con el esqueleto. Dame 2-3 fortalezas, 2-3 mejoras (menciona plano/path/postura si aplica) y un drill, en español, tono de coach.
        """
        Task {
            let text = await BirdieService.coach(prompt: prompt, images: images)
            await MainActor.run { s.birdieText = text; s.birdieLoading = false }
        }
    }
}

// ── PROGRESS ──
struct ProgressScreen: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        let sessions = s.history.sessions
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                backRow { s.screen = .home }
                Text("TU PROGRESO").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundColor(Theme.actionGreen)
                if sessions.isEmpty {
                    VStack(spacing: 10) {
                        Text("Aún no hay sesiones").font(Theme.serif(22)).foregroundColor(Theme.ink)
                        Text("Analiza tu primer swing y verás aquí tu evolución.")
                            .font(.system(size: 13.5)).foregroundColor(Theme.slate).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.top, 80)
                } else {
                    HStack(spacing: 10) {
                        statCard("\(s.history.last)", "Último")
                        statCard("\(s.history.avg)", "Promedio")
                        statCard("\(s.history.best)", "Mejor")
                    }
                    TrendChart(scores: sessions.map { $0.score })
                        .frame(height: 120).padding(16).background(Color.white).cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
                    Text("SESIONES (\(sessions.count))").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C))
                    ForEach(sessions.reversed()) { rec in
                        Button { s.openSession(rec) } label: {
                            HStack(spacing: 12) {
                                Text("\(rec.score)").font(Theme.serif(18)).foregroundColor(Theme.darkGreen)
                                    .frame(width: 40, height: 40).background(Color(hex: 0xF1F2EC)).cornerRadius(11)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(rec.club.label) · \(rec.angle.short)").font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.ink)
                                    Text(rec.shape?.shape ?? "—").font(.system(size: 11)).foregroundColor(Color(hex: 0x9AA39C))
                                }
                                Spacer()
                                Text(rec.date, format: .dateTime.day().month().hour().minute())
                                    .font(Theme.mono(10)).foregroundColor(Color(hex: 0xB3BBB4))
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0xC8D0C8))
                            }
                            .padding(12).background(Color.white).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder))
                        }
                        .contextMenu {
                            Button(role: .destructive) { s.deleteSession(rec.id) } label: {
                                Label("Eliminar sesión", systemImage: "trash")
                            }
                        }
                    }
                }
                Text("Mantén presionada una sesión para eliminarla.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: 0xB3BBB4))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)

                // Datos para mejorar la IA (correcciones de checkpoints)
                if s.trainingCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATOS PARA MEJORAR LA IA").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundColor(Color(hex: 0x9AA39C))
                        Text("\(s.trainingCount) correcciones guardadas. Cada vez que ajustas un checkpoint, enseñas al sistema. Expórtalas para entrenar el modelo.")
                            .font(.system(size: 11.5)).foregroundColor(Theme.slate).fixedSize(horizontal: false, vertical: true)
                        ShareLink(item: TrainingStore.shared.url) {
                            HStack { Image(systemName: "square.and.arrow.up"); Text("Exportar datos (\(s.trainingCount))") }
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.darkGreen)
                                .frame(maxWidth: .infinity).padding(11)
                                .background(Color(hex: 0xEAF6EC)).cornerRadius(12)
                        }
                    }
                    .padding(14).background(Color.white).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder)).padding(.top, 8)
                }
            }.padding(20).padding(.top, 30)
        }.background(Theme.cream.ignoresSafeArea())
    }
    func statCard(_ big: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(big).font(Theme.serif(26)).foregroundColor(Theme.ink)
            Text(label.uppercased()).font(.system(size: 9)).foregroundColor(Color(hex: 0x9AA39C))
        }.frame(maxWidth: .infinity).padding(12).background(Color.white).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder))
    }
}

struct TrendChart: View {
    let scores: [Int]
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, pad: CGFloat = 8
            let mn = CGFloat(scores.min() ?? 0), mx = CGFloat(scores.max() ?? 100)
            let range = max(1, mx - mn)
            let n = scores.count
            Path { p in
                for (i, sc) in scores.enumerated() {
                    let x = n == 1 ? w/2 : pad + CGFloat(i) * (w - 2*pad) / CGFloat(n - 1)
                    let y = h - pad - (CGFloat(sc) - mn) / range * (h - 2*pad)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }.stroke(Theme.actionGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// ── Ajuste manual de checkpoints (scrubber) ──
struct ScrubView: View {
    @EnvironmentObject var s: AppState
    @Environment(\.dismiss) var dismiss
    @State private var idx: Int = 0
    @State private var preview: UIImage?
    @State private var target: String = "top"

    var series: [FrameSample] { s.result?.series ?? [] }
    let targets = [("address","Address"),("top","Top"),("impact","Impacto"),("finish","Finish")]

    var body: some View {
        VStack(spacing: 14) {
            Text("Ajustar checkpoints").font(Theme.serif(20)).foregroundColor(Theme.ink).padding(.top, 8)
            Text("Elige cuál ajustar y desliza al frame correcto")
                .font(.system(size: 12)).foregroundColor(Theme.slate)
            Picker("", selection: $target) {
                ForEach(targets, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: target) { _ in idx = currentIndex() }

            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.black)
                if let p = preview {
                    Image(uiImage: p).resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(height: 340).cornerRadius(14)

            HStack(spacing: 10) {
                Button { idx = max(0, idx - 1) } label: { Image(systemName: "chevron.left").frame(width: 38, height: 38).background(Color(hex: 0xF1F2EC)).clipShape(Circle()) }
                Slider(value: Binding(get: { Double(idx) }, set: { idx = Int($0.rounded()) }),
                       in: 0...Double(max(1, series.count - 1)))
                .tint(Theme.actionGreen)
                Button { idx = min(series.count - 1, idx + 1) } label: { Image(systemName: "chevron.right").frame(width: 38, height: 38).background(Color(hex: 0xF1F2EC)).clipShape(Circle()) }
            }
            Text("frame \(idx + 1)/\(series.count) · t=\(String(format: "%.2f", series.indices.contains(idx) ? series[idx].t : 0))s")
                .font(Theme.mono(11)).foregroundColor(Theme.slate)

            Button {
                s.updateCheckpoint(target, index: idx, image: preview?.cgImage)
                dismiss()
            } label: {
                Text("Fijar \(label(target)) en este frame").font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: 0x08311C)).frame(maxWidth: .infinity).padding(15)
                    .background(Theme.actionGreen).cornerRadius(13)
            }
            Button("Cancelar") { dismiss() }.foregroundColor(Theme.slate).padding(.bottom, 6)
        }
        .padding(18)
        .onAppear { idx = currentIndex() }
        .task(id: idx) { await loadPreview(idx) }
    }

    func label(_ k: String) -> String { targets.first { $0.0 == k }?.1 ?? k }

    func currentIndex() -> Int {
        guard let cp = s.result?.checkpoints else { return 0 }
        switch target { case "address": return cp.address; case "top": return cp.top
        case "impact": return cp.impact; default: return cp.finish }
    }

    func loadPreview(_ i: Int) async {
        guard let url = s.result?.videoURL, series.indices.contains(i) else { return }
        let frame = series[i]
        let rotation = s.result?.rotation ?? 0
        let paths = PoseAnalyzer.swingPaths(series, checkpoints: s.result?.checkpoints)
        let ui: UIImage? = await Task.detached {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            gen.maximumSize = CGSize(width: 1080, height: 1080)
            let t = CMTime(seconds: frame.t, preferredTimescale: 600)
            guard let raw = try? gen.copyCGImage(at: t, actualTime: nil) else { return nil }
            let cg = PoseAnalyzer.prepareFrame(raw, rotation: rotation)
            let ov = PoseAnalyzer.renderOverlay(on: cg, points: frame.points, scores: frame.scores,
                                                pathBack: paths.back, pathDown: paths.down)
            return UIImage(cgImage: ov)
        }.value
        if let ui = ui { preview = ui }
    }
}

// Diagrama: trayectoria real de manos (backswing verde + bajada ámbar) vs la
// línea de plano ideal (punteada) que deberías seguir aproximadamente.
struct PlaneDiagram: View {
    let back: [CGPoint]
    let down: [CGPoint]
    let idealAngle: Double

    var body: some View {
        Canvas { ctx, size in
            let all = back + down
            guard all.count > 1 else { return }
            let xs = all.map { $0.x }, ys = all.map { $0.y }
            let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
            let bw = max(1, maxX - minX), bh = max(1, maxY - minY)
            let pad: CGFloat = 18
            let sc = min((size.width - 2*pad) / bw, (size.height - 2*pad) / bh)
            let offX = (size.width - bw * sc) / 2
            let offY = (size.height - bh * sc) / 2
            func map(_ p: CGPoint) -> CGPoint { CGPoint(x: offX + (p.x - minX) * sc, y: offY + (p.y - minY) * sc) }

            func strokePts(_ pts: [CGPoint], _ color: Color, _ w: CGFloat) {
                guard pts.count > 1 else { return }
                var path = Path(); path.move(to: map(pts[0]))
                for p in pts.dropFirst() { path.addLine(to: map(p)) }
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
            }

            // Línea de plano ideal (punteada) a través del punto de address
            if let a = back.first ?? down.first {
                let c = map(a)
                let rad = idealAngle * .pi / 180
                let L = max(size.width, size.height)
                let dx = cos(rad) * L, dy = -sin(rad) * L
                var ip = Path()
                ip.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
                ip.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
                ctx.stroke(ip, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }

            // Trayectoria real
            strokePts(back, Color(hex: 0x7FD08A), 3)
            strokePts(down, Color(hex: 0xF5A03A), 3.5)

            // Marcadores address/impacto
            if let a = back.first ?? down.first {
                let p = map(a)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x-4, y: p.y-4, width: 8, height: 8)), with: .color(.white))
            }
        }
    }
}
