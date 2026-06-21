import SwiftUI
import AVKit
import AVFoundation

// Vista previa del video elegido + recorte a un tramo (3–6 s) que cubra el swing.
struct PreviewTrimView: View {
    @EnvironmentObject var s: AppState
    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var len: Double = 4

    var maxStart: Double { max(0, duration - len) }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                backRow { stopAndBack() }
                Text("REVISA Y RECORTA").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundColor(Theme.actionGreen)
                Text("Recorta el swing").font(Theme.serif(28)).foregroundColor(Theme.ink)
                Text("Deja un tramo corto que cubra desde el address hasta el finish. Mejor análisis y más rápido.")
                    .font(.system(size: 13)).foregroundColor(Theme.slate)

                if let p = player {
                    VideoPlayer(player: p).frame(height: 320).cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color.black).frame(height: 320)
                        .overlay(ProgressView().tint(.white))
                }

                // Duración del tramo
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duración del tramo: \(Int(len)) s").font(.system(size: 12.5, weight: .medium)).foregroundColor(Color(hex: 0x3C463F))
                    Picker("", selection: $len) {
                        ForEach([3.0, 4.0, 5.0, 6.0], id: \.self) { Text("\(Int($0))s").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: len) { _ in start = min(start, maxStart); seek(start) }
                }

                // Inicio del tramo
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Inicio").font(.system(size: 12.5, weight: .medium)).foregroundColor(Color(hex: 0x3C463F))
                        Spacer()
                        Text(String(format: "%.1fs → %.1fs", start, min(duration, start + len)))
                            .font(Theme.mono(11)).foregroundColor(Theme.slate)
                    }
                    Slider(value: $start, in: 0...max(0.1, maxStart)) { editing in
                        if !editing { previewSegment() }
                    }
                    .tint(Theme.actionGreen)
                    .onChange(of: start) { v in seek(v) }
                }

                Spacer()

                Button { confirm() } label: {
                    Text("Analizar este tramo").font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: 0x08311C)).frame(maxWidth: .infinity).padding(17)
                        .background(Theme.actionGreen).cornerRadius(15)
                }
                Button { stopAndBack() } label: {
                    Text("Elegir otro video").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.darkGreen).frame(maxWidth: .infinity).padding(12)
                        .background(Color(hex: 0xEAF6EC)).cornerRadius(12)
                }
            }
            .padding(20).padding(.top, 20)
        }
        .task { await load() }
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
            seek(0)
            p.play()
        }
    }

    func seek(_ t: Double) {
        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // Reproduce solo el tramo seleccionado una vez
    func previewSegment() {
        guard let p = player else { return }
        seek(start); p.play()
    }

    func confirm() {
        guard let url = s.pickedURL else { return }
        player?.pause()
        s.analyze(url: url, start: start, len: len)
    }

    func stopAndBack() {
        player?.pause()
        player = nil
        s.screen = .upload
    }
}
