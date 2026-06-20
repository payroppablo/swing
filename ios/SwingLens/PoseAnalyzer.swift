import Foundation
import AVFoundation
import Vision
import CoreGraphics

// Motor de análisis: extrae frames con AVAssetImageGenerator (exactos en iOS),
// corre Vision (VNDetectHumanBodyPoseRequest), arma la serie y detecta los 4
// checkpoints + plano/postura + métricas. Puerto de la lógica del prototipo web.
struct PoseAnalyzer {

    static let jointMap: [VNHumanBodyPoseObservation.JointName: String] = [
        .nose: "nose",
        .leftShoulder: "left_shoulder", .rightShoulder: "right_shoulder",
        .leftElbow: "left_elbow", .rightElbow: "right_elbow",
        .leftWrist: "left_wrist", .rightWrist: "right_wrist",
        .leftHip: "left_hip", .rightHip: "right_hip",
        .leftKnee: "left_knee", .rightKnee: "right_knee",
        .leftAnkle: "left_ankle", .rightAnkle: "right_ankle",
    ]

    static func analyze(url: URL, club: Club, angle: CameraAngle,
                        progress: @escaping (Double) -> Void) async -> AnalysisResult? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let durationTime = try? await asset.load(.duration) else { return nil }
        let size = (try? await track.load(.naturalSize)) ?? CGSize(width: 720, height: 1280)
        let vw = abs(size.width), vh = abs(size.height)
        let duration = min(CMTimeGetSeconds(durationTime), 10)
        if duration <= 0 { return nil }

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        gen.maximumSize = CGSize(width: 640, height: 640)

        let step = 1.0 / 30.0
        var series: [FrameSample] = []
        var prevShoulder: Double? = nil
        var prevHip: Double? = nil

        let request = VNDetectHumanBodyPoseRequest()
        var t = 0.0
        while t <= duration {
            let cmt = CMTime(seconds: t, preferredTimescale: 600)
            guard let cg = try? gen.copyCGImage(at: cmt, actualTime: nil) else { t += step; continue }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])

            var pts: [String: CGPoint] = [:]
            var scs: [String: Double] = [:]
            if let obs = request.results?.first as? VNHumanBodyPoseObservation,
               let recognized = try? obs.recognizedPoints(.all) {
                let w = CGFloat(cg.width), h = CGFloat(cg.height)
                for (vKey, name) in jointMap {
                    if let p = recognized[vKey], p.confidence > 0.05 {
                        // Vision: normalizado, origen abajo-izq, y arriba -> a coords imagen (y abajo)
                        pts[name] = CGPoint(x: p.location.x * w, y: (1 - p.location.y) * h)
                        scs[name] = Double(p.confidence)
                    }
                }
            }

            var sa = shoulderAngleRaw(pts, scs)
            sa = correctedAngle(sa, prevShoulder); if sa != nil { prevShoulder = sa }
            var ha = hipAngleRaw(pts, scs)
            ha = correctedAngle(ha, prevHip); if ha != nil { prevHip = ha }
            let sp = spineTiltRaw(pts, scs)

            series.append(FrameSample(t: t, points: pts, scores: scs,
                                      shoulderAngle: sa, hipAngle: ha, spineTilt: sp, image: nil))
            progress(min(0.95, t / duration))
            t += step
        }

        if series.count < 6 { return nil }

        var checkpoints = detectCheckpoints(series)
        // Rellenar imágenes exactas de los 4 checkpoints (native = preciso)
        if let cp = checkpoints {
            for idx in [cp.address, cp.top, cp.impact, cp.finish] {
                let cmt = CMTime(seconds: series[idx].t, preferredTimescale: 600)
                if let cg = try? gen.copyCGImage(at: cmt, actualTime: nil) {
                    series[idx].image = cg
                }
            }
        }

        let metrics = calcMetrics(series, vw: Double(vw), vh: Double(vh), angle: angle)
        let shape = analyzeShape(series, checkpoints: checkpoints)
        progress(1.0)

        return AnalysisResult(
            score: metrics.score, headStability: metrics.head, hipRotation: metrics.hip,
            tempo: metrics.tempo, followThrough: metrics.ft, setup: metrics.setup,
            tempoRatio: metrics.tempoRatio, hipDeg: metrics.hipDeg, headMovCm: metrics.headMovCm,
            club: club, angle: angle, series: series, checkpoints: checkpoints, shape: shape
        )
    }

    // ── ángulos ──
    static func angleDiff(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }
    static func flip180(_ a: Double) -> Double { let f = a + 180; return f > 180 ? f - 360 : f }
    static func correctedAngle(_ raw: Double?, _ prev: Double?) -> Double? {
        guard let raw = raw else { return nil }
        guard let prev = prev else { return raw }
        let alt = flip180(raw)
        return angleDiff(alt, prev) < angleDiff(raw, prev) ? alt : raw
    }
    static func line(_ p: [String: CGPoint], _ s: [String: Double], _ a: String, _ b: String, _ minS: Double = 0.25) -> Double? {
        guard let pa = p[a], let pb = p[b], (s[a] ?? 0) > minS, (s[b] ?? 0) > minS else { return nil }
        return atan2(Double(pb.y - pa.y), Double(pb.x - pa.x)) * 180 / .pi
    }
    static func shoulderAngleRaw(_ p: [String: CGPoint], _ s: [String: Double]) -> Double? {
        line(p, s, "left_shoulder", "right_shoulder")
    }
    static func hipAngleRaw(_ p: [String: CGPoint], _ s: [String: Double]) -> Double? {
        line(p, s, "left_hip", "right_hip")
    }
    static func spineTiltRaw(_ p: [String: CGPoint], _ s: [String: Double]) -> Double? {
        guard let ls = p["left_shoulder"], let rs = p["right_shoulder"],
              let lh = p["left_hip"], let rh = p["right_hip"] else { return nil }
        for k in ["left_shoulder","right_shoulder","left_hip","right_hip"] where (s[k] ?? 0) < 0.25 { return nil }
        let ms = CGPoint(x: (ls.x+rs.x)/2, y: (ls.y+rs.y)/2)
        let mh = CGPoint(x: (lh.x+rh.x)/2, y: (lh.y+rh.y)/2)
        let ang = atan2(Double(mh.y - ms.y), Double(mh.x - ms.x)) * 180 / .pi
        return angleDiff(ang, 90)
    }

    // ── señales ──
    static func bestWristXY(_ f: FrameSample) -> CGPoint? {
        var best: CGPoint? = nil; var bestS = 0.15
        for n in ["left_wrist","right_wrist"] {
            if let pt = f.points[n], let sc = f.scores[n], sc > bestS { bestS = sc; best = pt }
        }
        return best
    }
    static func avgWristY(_ f: FrameSample) -> Double? { bestWristXY(f).map { Double($0.y) } }

    static func bodyMotion(_ a: FrameSample, _ b: FrameSample) -> Double? {
        let names = ["left_shoulder","right_shoulder","left_elbow","right_elbow",
                     "left_wrist","right_wrist","left_hip","right_hip","left_knee","right_knee","nose"]
        var ds: [Double] = []
        for n in names {
            if let pa = a.points[n], let pb = b.points[n], (a.scores[n] ?? 0) > 0.3, (b.scores[n] ?? 0) > 0.3 {
                ds.append(hypot(Double(pb.x - pa.x), Double(pb.y - pa.y)))
            }
        }
        guard !ds.isEmpty else { return nil }
        ds.sort()
        return ds[ds.count / 2]
    }

    static func interpolateNulls(_ arr: [Double?]) -> [Double?] {
        var out = arr; var last = -1
        for i in 0..<out.count {
            if out[i] != nil {
                if last >= 0 && i - last > 1 {
                    let a = out[last]!, b = out[i]!
                    for j in (last+1)..<i { out[j] = a + (b - a) * Double(j - last) / Double(i - last) }
                }
                last = i
            }
        }
        if let first = out.firstIndex(where: { $0 != nil }), first > 0 {
            for i in 0..<first { out[i] = out[first] }
        }
        if let lv = out.lastIndex(where: { $0 != nil }), lv < out.count - 1 {
            for i in (lv+1)..<out.count { out[i] = out[lv] }
        }
        return out
    }
    static func smooth1D(_ arr: [Double?], _ win: Int) -> [Double?] {
        var out = arr
        for i in 0..<arr.count {
            var sum = 0.0, c = 0
            for j in max(0, i-win)...min(arr.count-1, i+win) { if let v = arr[j] { sum += v; c += 1 } }
            out[i] = c > 0 ? sum / Double(c) : nil
        }
        return out
    }
    static func walkToExtreme(_ arr: [Double?], _ start: Int, _ dir: Int, _ findMax: Bool, _ tol: Double) -> Int {
        guard arr.indices.contains(start), var bestV = arr[start] else { return start }
        var bestI = start, i = start
        while true {
            let next = i + dir
            guard arr.indices.contains(next), let v = arr[next] else { break }
            if findMax ? v > bestV : v < bestV { bestV = v; bestI = next }
            if findMax ? (bestV - v > tol) : (v - bestV > tol) { break }
            i = next
        }
        return bestI
    }

    static func detectCheckpoints(_ series: [FrameSample]) -> Checkpoints? {
        let n = series.count
        if n < 6 { return nil }
        let t = series.map { $0.t }
        // velocidad corporal (mediana / dt)
        var motion: [Double?] = [nil]
        for i in 1..<n {
            let d = bodyMotion(series[i-1], series[i]); let dt = t[i] - t[i-1]
            motion.append((d != nil && dt > 0) ? d! / dt : nil)
        }
        let sm = smooth1D(motion, 2)
        var dsIdx = -1; var maxM = -Double.infinity
        for i in 2..<(n-1) { if let v = sm[i], v > maxM { maxM = v; dsIdx = i } }
        if dsIdx < 0 { return nil }

        let rawY: [Double?] = series.map { avgWristY($0) }
        let haveWrist = rawY.compactMap { $0 }.count >= Int(Double(n) * 0.3)
        let wy = smooth1D(interpolateNulls(rawY), 3)
        let ys = wy.compactMap { $0 }
        let yRange = (ys.max() ?? 0) - (ys.min() ?? 0)
        let tol = max(2.0, yRange * 0.05)
        let stepN = max(1, Int(0.2 / max(0.001, t[1] - t[0])))

        var topIdx: Int, impactIdx: Int, finishIdx: Int, addrIdx: Int
        if haveWrist && yRange > 10 {
            impactIdx = walkToExtreme(wy, dsIdx, 1, true, tol)
            topIdx    = walkToExtreme(wy, dsIdx, -1, false, tol)
            finishIdx = walkToExtreme(wy, min(n-1, impactIdx+1), 1, false, tol)
            addrIdx   = walkToExtreme(wy, topIdx, -1, true, tol)
        } else {
            topIdx = max(0, dsIdx - stepN)
            impactIdx = min(n-1, dsIdx + max(1, Int(0.08 / max(0.001, t[1]-t[0]))))
            finishIdx = n - 1
            addrIdx = 0
        }
        var idx = [addrIdx, topIdx, impactIdx, finishIdx]
        for i in 1..<4 where idx[i] <= idx[i-1] { idx[i] = min(n-1, idx[i-1] + 1) }
        let dbg = String(format: "a%.2f t%.2f i%.2f f%.2f ds%.2f w:%@ %df",
                         t[idx[0]], t[idx[1]], t[idx[2]], t[idx[3]], t[dsIdx], haveWrist ? "y" : "n", n)
        return Checkpoints(address: idx[0], top: idx[1], impact: idx[2], finish: idx[3], debug: dbg)
    }

    static func analyzeShape(_ series: [FrameSample], checkpoints: Checkpoints?) -> ShapeInfo? {
        guard let cp = checkpoints else { return nil }
        let A = series[cp.address], T = series[cp.top], I = series[cp.impact]
        let spineAddr = A.spineTilt, spineImp = I.spineTilt
        let spineRet = (spineAddr != nil && spineImp != nil) ? abs(spineImp! - spineAddr!) : nil

        var info = ShapeInfo(planeAngle: nil, pathDelta: nil, pathLabel: nil, shape: nil,
                             shapeNote: nil, spineAddr: spineAddr, spineRet: spineRet)
        guard let wA = bestWristXY(A), let wT = bestWristXY(T), let wI = bestWristXY(I) else { return info }
        func ang(_ p: CGPoint, _ q: CGPoint) -> Double {
            abs(atan2(abs(Double(q.y - p.y)), max(0.0001, abs(Double(q.x - p.x)))) * 180 / .pi)
        }
        let back = ang(wA, wT), down = ang(wT, wI)
        info.planeAngle = Int(back.rounded())
        let delta = Int((down - back).rounded())
        info.pathDelta = delta
        if delta > 8 {
            info.pathLabel = "Over the top · out-to-in"; info.shape = "Tiende a fade / slice"
            info.shapeNote = "El downswing entra más empinado que el backswing."
        } else if delta < -8 {
            info.pathLabel = "Por dentro · in-to-out"; info.shape = "Tiende a draw / hook"
            info.shapeNote = "El downswing cae por dentro del plano."
        } else {
            info.pathLabel = "On plane · neutral"; info.shape = "Trayectoria recta"
            info.shapeNote = "Backswing y downswing van por el mismo plano."
        }
        return info
    }

    // ── métricas ──
    static func calcMetrics(_ series: [FrameSample], vw: Double, vh: Double, angle: CameraAngle)
        -> (score: Int, head: Int, hip: Int, tempo: Int, ft: Int, setup: Int, tempoRatio: String, hipDeg: Int, headMovCm: Double) {

        // head stability: desviación en x de la nariz
        let noseX: [Double] = series.compactMap { f in
            guard (f.scores["nose"] ?? 0) > 0.25, let n = f.points["nose"] else { return nil }
            return Double(n.x) / vw
        }
        var head = 70, headCm = 3.0
        if noseX.count > 3 {
            let m = noseX.reduce(0,+)/Double(noseX.count)
            let sd = (noseX.reduce(0){ $0 + ($1-m)*($1-m) }/Double(noseX.count)).squareRoot()
            head = Int(max(20, min(95, 100 - sd*380)))
            headCm = (sd * vw * 0.075 * 10).rounded() / 10
        }

        // hip
        var hip = 65, hipDeg = 28
        if angle == .faceOn {
            let angs = series.compactMap { f -> Double? in
                guard let lh = f.points["left_hip"], let rh = f.points["right_hip"],
                      (f.scores["left_hip"] ?? 0) > 0.25, (f.scores["right_hip"] ?? 0) > 0.25 else { return nil }
                return abs(atan2(Double(rh.y-lh.y), Double(rh.x-lh.x)) * 180 / .pi)
            }
            if angs.count > 2 { hipDeg = Int(angs.max()!.rounded()); hip = Int(min(95, Double(hipDeg)*2.1)) }
        } else {
            let xs = series.compactMap { f -> Double? in
                guard let lh = f.points["left_hip"], let rh = f.points["right_hip"],
                      (f.scores["left_hip"] ?? 0) > 0.2, (f.scores["right_hip"] ?? 0) > 0.2 else { return nil }
                return (Double(lh.x)+Double(rh.x))/2/vw
            }
            if xs.count > 3 {
                let m = xs.reduce(0,+)/Double(xs.count)
                let sd = (xs.reduce(0){ $0 + ($1-m)*($1-m) }/Double(xs.count)).squareRoot()
                hipDeg = Int((sd*600).rounded()); hip = Int(max(30, min(90, sd*1200)))
            }
        }

        // tempo
        let wristH = series.compactMap { avgWristY($0).map { -$0 } } // -y => más alto = mayor
        var tempo = 78; var tempoRatio = "3.1:1"
        if wristH.count > 4 {
            let peakIdx = wristH.firstIndex(of: wristH.max()!) ?? 0
            let ratio = Double(peakIdx) / Double(max(1, wristH.count - peakIdx))
            tempo = Int(max(40, min(95, 100 - abs(ratio - 3.0)*22)))
            tempoRatio = String(format: "%.1f:1", ratio)
        }

        // follow-through (varianza muñeca último 25%)
        var ft = 68
        let last = Array(series.suffix(max(1, series.count/4)))
        let fx = last.compactMap { f in bestWristXY(f).map { Double($0.x)/vw } }
        if fx.count > 1 {
            let m = fx.reduce(0,+)/Double(fx.count)
            let sd = (fx.reduce(0){ $0 + ($1-m)*($1-m) }/Double(fx.count)).squareRoot()
            ft = Int(max(40, min(92, 100 - sd*280)))
        }

        // setup (simetría hombros primer 25%)
        var setup = 82
        let first = Array(series.prefix(max(1, series.count/4)))
        let dif = first.compactMap { f -> Double? in
            guard let ls = f.points["left_shoulder"], let rs = f.points["right_shoulder"],
                  (f.scores["left_shoulder"] ?? 0) > 0.25, (f.scores["right_shoulder"] ?? 0) > 0.25 else { return nil }
            return abs(Double(ls.y - rs.y))/vh
        }
        if !dif.isEmpty {
            let avg = dif.reduce(0,+)/Double(dif.count)
            setup = Int(max(50, min(95, 100 - avg*300)))
        }

        let score = Int((Double(head)*0.25 + Double(hip)*0.25 + Double(tempo)*0.25 + Double(ft)*0.15 + Double(setup)*0.10).rounded())
        return (score, head, hip, tempo, ft, setup, tempoRatio, hipDeg, headCm)
    }
}
