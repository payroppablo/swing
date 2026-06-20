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

enum Screen { case home, upload, analysis, results, progress }

@MainActor
final class AppState: ObservableObject {
    @Published var screen: Screen = .home
    @Published var club: Club = .driver
    @Published var angle: CameraAngle = .dtl
    @Published var result: AnalysisResult?
    @Published var progress: Double = 0
    @Published var birdieText: String = ""
    @Published var birdieLoading = false
    let history = HistoryStore()

    func analyze(url: URL) {
        screen = .analysis
        progress = 0
        let club = self.club, angle = self.angle
        Task.detached(priority: .userInitiated) {
            let res = await PoseAnalyzer.analyze(url: url, club: club, angle: angle) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run {
                if let res = res {
                    self.result = res
                    self.history.add(res)
                    self.birdieText = ""
                    self.screen = .results
                } else {
                    self.screen = .upload
                }
            }
        }
    }
}
