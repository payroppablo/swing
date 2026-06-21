import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// Router
struct RootView: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        ZStack {
            switch s.screen {
            case .home:     HomeView()
            case .upload:   UploadView()
            case .analysis: AnalysisView()
            case .results:  ResultsView()
            case .progress: ProgressScreen()
            case .drills:   DrillsView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: s.screen)
    }
}

// ── HOME ──
struct HomeView: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.darkGreen, Color(hex: 0x0D241C)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text("SwingLens Golf")
                    .font(Theme.serif(40)).foregroundColor(.white)

                // Birdie · caddie (ícono placeholder + su frase, estilo web)
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.lightGreen.opacity(0.18))
                        Circle().stroke(Theme.lightGreen.opacity(0.5), lineWidth: 1.5)
                        Image(systemName: "figure.golf").font(.system(size: 26)).foregroundColor(Theme.lightGreen)
                    }
                    .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BIRDIE · TU CADDIE")
                            .font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundColor(Theme.lightGreen)
                        Text("\"Listo cuando quieras — mándame un swing y te leo cada detalle.\"")
                            .font(.system(size: 14, design: .serif)).italic().foregroundColor(Color(hex: 0xEAF3EB))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(16)
                }
                Spacer()
                menuButton("Subir swing", subtitle: "Graba o elige de la galería",
                           bg: Theme.actionGreen, fg: Color(hex: 0x08311C)) { s.screen = .upload }
                menuButton("Tu progreso", subtitle: "Historial y evolución de tu score",
                           bg: .white.opacity(0.08), fg: .white) { s.screen = .progress }
                menuButton("Drills & Tips", subtitle: "Ejercicios para sentir y mejorar",
                           bg: .white.opacity(0.08), fg: .white) { s.screen = .drills }
                Spacer().frame(height: 20)
            }
            .padding(28)
        }
    }
    func menuButton(_ title: String, subtitle: String, bg: Color, fg: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(fg)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(fg.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(fg.opacity(0.7))
            }
            .padding(16)
            .background(bg)
            .cornerRadius(18)
        }
    }
}

// ── UPLOAD ──
struct UploadView: View {
    @EnvironmentObject var s: AppState
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                backRow { s.screen = .home }
                Text("STEP 1 OF 2").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundColor(Theme.actionGreen)
                Text("Sube tu swing").font(Theme.serif(34)).foregroundColor(Theme.ink)

                segmented(title: "Ángulo", options: [("Down-the-line", CameraAngle.dtl), ("Face-on", .faceOn)],
                          selection: s.angle) { s.angle = $0 }
                segmented(title: "Bastón", options: Club.allCases.map { ($0.label, $0) },
                          selection: s.club) { s.club = $0 }

                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Label("Elegir video del swing", systemImage: "video.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: 0x08311C))
                        .frame(maxWidth: .infinity).padding(17)
                        .background(Theme.actionGreen).cornerRadius(15)
                }
                Text("Mejor resultado: cámara fija · una repetición limpia · build iOS 1")
                    .font(Theme.mono(11)).foregroundColor(Color(hex: 0x9AA39C))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .onChange(of: pickerItem) { item in
            guard let item = item else { return }
            Task {
                if let movie = try? await item.loadTransferable(type: Movie.self) {
                    await MainActor.run { s.analyze(url: movie.url) }
                }
            }
        }
    }

    @ViewBuilder
    func segmented<T: Equatable>(title: String, options: [(String, T)], selection: T, onPick: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    Button { onPick(opt.1) } label: {
                        Text(opt.0).font(.system(size: 12.5, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .foregroundColor(selection == opt.1 ? Theme.darkGreen : Color(hex: 0x6B756F))
                            .background(selection == opt.1 ? Color.white : Color.clear)
                            .cornerRadius(9)
                    }
                }
            }
            .padding(4).background(Color(hex: 0xECEAE3)).cornerRadius(12)
        }
    }
}

// ── ANALYSIS ──
struct AnalysisView: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x214D3A), Color(hex: 0x0D241C)],
                           center: .center, startRadius: 10, endRadius: 500).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("ANALYZING").font(.system(size: 11, weight: .semibold)).tracking(4).foregroundColor(Theme.lightGreen)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 10).frame(width: 150, height: 150)
                    Circle().trim(from: 0, to: s.progress)
                        .stroke(Theme.lightGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 150, height: 150).rotationEffect(.degrees(-90))
                    Text("\(Int(s.progress*100))%").font(Theme.serif(34)).foregroundColor(.white)
                }
                Text("Analizando tu swing…").font(Theme.serif(22)).foregroundColor(.white)
            }
        }
    }
}

// helpers compartidos
func backRow(_ action: @escaping () -> Void) -> some View {
    HStack(spacing: 12) {
        Button(action: action) {
            Image(systemName: "chevron.left").foregroundColor(Theme.darkGreen)
                .frame(width: 38, height: 38).background(Color.white).clipShape(Circle())
                .overlay(Circle().stroke(Theme.cardBorder))
        }
        Spacer()
    }
}
