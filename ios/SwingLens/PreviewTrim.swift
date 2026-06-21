import SwiftUI
import AVKit
import AVFoundation

// Vista previa del video + recorte claro a un tramo (3–6 s) con tira de
// miniaturas y rango resaltado (de dónde a dónde).
struct PreviewTrimView: View {
    @EnvironmentObject var s: AppState
    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var len: Double = 4
    @State private var thumbs: [UIImage] = []

    var maxStart: Double { max(0.0001, duration - len) }
    var end: Double { min(duration, start + len) }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                backRow { stopAndBack() }
                Text("REVISA Y RECORTA").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundColor(Theme.actionGreen)
                Text("Recorta el swing").font(Theme.serif(28)).foregroundColor(Theme.ink)
                Text("Deja un tramo que cubra del address al finish.").font(.system(size: 13)).foregroundColor(Theme.slate)

                if let p = player {
                    VideoPlayer(player: p).frame(height: 300).cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(Color.black).frame(height: 300)
                        .overlay(ProgressView().tint(.white))
                }

                // Tira de miniaturas con el tramo resaltado
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            if thumbs.isEmpty {
                                Rectangle().fill(Color(hex: 0x0D241C))
                            } else {
                                ForEach(Array(thumbs.enumerated()), id: \.offset) { _, im in
                                    Image(uiImage: im).resizable().scaledToFill()
                                        .frame(width: w / CGFloat(thumbs.count), height: 56).clipped()
                                }
                            }
                        }
                        .frame(width: w, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                        // Oscurecer fuera del tramo
                        if duration > 0 {
                            let x0 = CGFloat(start / duration) * w
                            let x1 = CGFloat(end / duration) * w
                            Color.black.opacity(0.45).frame(width: max(0, x0), height: 56)
                            Color.black.opacity(0.45).frame(width: max(0, w - x1), height: 56).offset(x: x1)
                            // Marco del tramo seleccionado
                            RoundedRectangle(cornerRadius: 8).stroke(Theme.actionGreen, lineWidth: 3)
                                .frame(width: max(2, x1 - x0), height: 56).offset(x: x0)
                        }
                    }
                }
                .frame(height: 56)

                // Etiquetas claras de inicio/fin
                HStack {
                    label("INICIO", String(format: "%.1f s", start))
                    Spacer()
                    Image(systemName: "arrow.right").foregroundColor(Color(hex: 0xB3BBB4))
                    Spacer()
                    label("FIN", String(format: "%.1f s", end))
                    Spacer()
                    label("DURA", "\(Int(len)) s")
                }

                // Duración del tramo
                Picker("", selection: $len) {
                    ForEach([3.0, 4.0, 5.0, 6.0], id: \.self) { Text("\(Int($0))s").tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: len) { _ in start = min(start, maxStart); seek(start) }

                // Mover el inicio
                Slider(value: $start, in: 0...maxStart) { editing in if !editing { previewSegment() } }
                    .tint(Theme.actionGreen)
                    .onChange(of: start) { v in seek(v) }

                Spacer()

                Button { confirm() } label: {
                    Text("Analizar este tramo").font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: 0x08311C)).frame(maxWidth: .infinity).padding(17)
                        .background(Theme.actionGreen).cornerRadius(15)
                        .shadow(color: Theme.actionGreen.opacity(0.3), radius: 10, y: 5)
                }
                Button { stopAndBack() } label: {
                    Text("Elegir otro video").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.darkGreen).frame(maxWidth: .infinity).padding(12)
                }
            }
            .padding(20).padding(.top, 20)
        }
        .task { await load() }
    }

    func label(_ tag: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(tag).font(.system(size: 8.5, weight: .bold)).tracking(1).foregroundColor(Color(hex: 0x9AA39C))
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Theme.darkGreen)
        }
    }

    func load() async {
        guard let url = s.pickedURL else { return }
        let asset = AVURLAsset(url: url)
        let d = (try? await asset.load(.duration)).map { CMTimeGetSeconds($0) } ?? 0
        await MainActor.run {
            duration = d
            len = min(4, max(2, d))
            start = 0
            let p = AVPlayer(url: url)
            player = p
            seek(0); p.play()
        }
        // Generar ~10 miniaturas
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 160, height: 160)
        var imgs: [UIImage] = []
        let n = 10
        for i in 0..<n {
            let t = d * (Double(i) + 0.5) / Double(n)
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
                imgs.append(UIImage(cgImage: cg))
            }
        }
        await MainActor.run { thumbs = imgs }
    }

    func seek(_ t: Double) {
        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func previewSegment() { guard let p = player else { return }; seek(start); p.play() }
    func confirm() {
        guard let url = s.pickedURL else { return }
        player?.pause()
        s.analyze(url: url, start: start, len: len)
    }
    func stopAndBack() { player?.pause(); player = nil; s.screen = .upload }
}
