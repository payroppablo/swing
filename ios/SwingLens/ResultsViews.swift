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
                if let r = r {
                    scoreHero(r)
                    checkpointsRow(r)
                    if let shape = r.shape { planeCard(shape, club: r.club) }
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
    }

    func scoreHero(_ r: AnalysisResult) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color(hex: 0xEAEDE5), lineWidth: 13).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: CGFloat(r.score)/100)
                    .stroke(Theme.actionGreen, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .frame(width: 150, height: 150).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(r.score)").font(Theme.serif(50)).foregroundColor(Theme.ink)
                    Text("SWING SCORE").font(.system(size: 9, weight: .medium)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
                }
            }
        }.frame(maxWidth: .infinity)
    }

    func checkpointsRow(_ r: AnalysisResult) -> some View {
        let labels = ["Address", "Top", "Impacto", "Finish"]
        let idxs: [Int] = r.checkpoints.map { [$0.address, $0.top, $0.impact, $0.finish] } ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("SWING CHECKPOINTS").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C))
            if let dbg = r.checkpoints?.debug { Text(dbg).font(Theme.mono(9)).foregroundColor(Color(hex: 0xB3BBB4)) }
            HStack(spacing: 7) {
                ForEach(0..<idxs.count, id: \.self) { i in
                    VStack(spacing: 4) {
                        if let cg = r.series[idxs[i]].image {
                            Image(uiImage: UIImage(cgImage: cg)).resizable().scaledToFill()
                                .frame(height: 110).frame(maxWidth: .infinity).clipped().cornerRadius(9)
                        } else {
                            Rectangle().fill(Color(hex: 0x0D241C)).frame(height: 110).cornerRadius(9)
                        }
                        Text(labels[i]).font(.system(size: 9.5, weight: .semibold)).foregroundColor(Color(hex: 0x6B756F))
                    }
                }
            }
        }
    }

    func planeCard(_ shape: ShapeInfo, club: Club) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PLANO · PATH · POSTURA").font(.system(size: 11, weight: .semibold)).tracking(2).foregroundColor(Color(hex: 0x9AA39C))
                Spacer()
                Text("ESTIMADO").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: 0x9A8458))
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Color(hex: 0xF5EFE0)).cornerRadius(99)
            }
            if let label = shape.pathLabel {
                Text(label).font(.system(size: 14.5, weight: .bold)).foregroundColor(Theme.ink)
                Text("\(shape.shape ?? "") — \(shape.shapeNote ?? "")").font(.system(size: 12.5)).foregroundColor(Theme.slate)
            }
            HStack(spacing: 10) {
                stat("\(shape.planeAngle.map { "\($0)°" } ?? "—")", "Plano manos", "ideal \(club.planeLo)–\(club.planeHi)°")
                stat(shape.spineRet.map { "±\(Int($0.rounded()))°" } ?? "—", "Postura", "address→impacto")
                stat(shape.spineAddr.map { "\(Int($0.rounded()))°" } ?? "—", "Spine address", "inclinación")
            }
            Text("Nota: Vision no ve el palo. El plano se estima de las manos; la forma es tendencia.")
                .font(.system(size: 10.5)).foregroundColor(Color(hex: 0x9AA39C))
        }
        .padding(16).background(Color.white).cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
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
        .padding(.vertical, 4).background(Color.white).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder))
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
        [
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
    }

    func drillFor(_ key: String) -> (String, String, String) {
        switch key {
        case "tempo":  return ("Cuenta 1-2-3", "Cuenta \"1-2\" subiendo y \"3\" bajando para grabar un ritmo 3:1.", "3 series · 10 swings · 5 min")
        case "setup":  return ("Chequeo al espejo", "Frente a un espejo, iguala columna neutra y hombros nivelados antes de cada repe.", "2 series · 8 reps · 4 min")
        case "head":   return ("Cabeza contra la pared", "En address apoya la cabeza en la pared y mantén el contacto en el backswing.", "3 series · 10 reps · 6 min")
        case "hip":    return ("Pump-and-Hold", "Pausa a mitad de bajada y sostén para grabar la secuencia de cadera antes del release.", "3 series · 10 reps · 5 min")
        default:        return ("Sostén el Finish", "Llega a un finish completo y sostén 3 segundos balanceado en el lado líder.", "3 series · 8 reps · 5 min")
        }
    }

    @ViewBuilder
    func coachContent(_ r: AnalysisResult) -> some View {
        let all = findings(r)
        let strengths = Array(all.filter { $0.score >= 70 }.sorted { $0.score > $1.score }.prefix(3))
        let focusRaw = all.filter { $0.score < 70 }.sorted { $0.score < $1.score }
        let focus = Array((focusRaw.isEmpty ? [all.min { $0.score < $1.score }!] : focusRaw).prefix(3))
        let strengthsShown = strengths.isEmpty ? [all.max { $0.score < $1.score }!] : strengths
        let drill = drillFor(focus.first?.key ?? "hip")

        VStack(alignment: .leading, spacing: 11) {
            Text("LO QUE HACES BIEN").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x3E8F58))
            ForEach(strengthsShown, id: \.key) { f in
                tipCard(icon: "checkmark.circle.fill", iconColor: Color(hex: 0x3E8F58),
                        title: f.sTitle, desc: f.sDesc, badge: "Fortaleza", badgeColor: Color(hex: 0x3E8F58),
                        score: f.score, scoreLabel: f.label, light: true)
            }
            Text("ÁREAS A MEJORAR").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Color(hex: 0x9AA39C)).padding(.top, 4)
            ForEach(focus, id: \.key) { f in
                let badge = f.score < 55 ? "Prioridad" : (f.score < 68 ? "Moderado" : "Menor")
                tipCard(icon: "scope", iconColor: Theme.lightGreen,
                        title: f.fTitle, desc: f.fDesc, badge: badge, badgeColor: Theme.amber,
                        score: f.score, scoreLabel: f.label, light: false)
            }
            // Drill recomendado
            VStack(alignment: .leading, spacing: 8) {
                Text("DRILL RECOMENDADO").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundColor(Theme.lightGreen)
                Text(drill.0).font(Theme.serif(22)).foregroundColor(.white)
                Text(drill.1).font(.system(size: 13.5)).foregroundColor(.white.opacity(0.85))
                Text(drill.2).font(Theme.mono(11)).foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(LinearGradient(colors: [Theme.darkGreen, Color(hex: 0x10301F)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(18)
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
                    }
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
