# SwingLens — App nativa iOS (SwiftUI + Vision)

Milestone 1: flujo completo nativo — elegir video → análisis de pose con
**Vision** (Apple) → checkpoints + plano/postura + métricas → resultados +
progreso + Birdie (vía el Cloudflare Worker). La extracción de frames usa
`AVAssetImageGenerator` (exacta en iOS, sin el problema de seek de Safari).

## Abrir en Xcode

1. Xcode → **File → New → Project → iOS → App**.
   - Product Name: `SwingLens`
   - Interface: **SwiftUI**, Language: **Swift**
   - Minimum Deployments: **iOS 16.0** o superior.
2. Borra el `ContentView.swift` y el `SwingLensApp.swift` que crea Xcode.
3. Arrastra a tu proyecto TODOS los archivos de esta carpeta `ios/SwingLens/`:
   - `SwingLensApp.swift`, `Theme.swift`, `Models.swift`, `PoseAnalyzer.swift`,
     `Stores.swift`, `Views.swift`, `ResultsViews.swift`
   - Marca **Copy items if needed** y tu target.
4. En **Signing & Capabilities** elige tu equipo (Apple ID gratis sirve para
   probar en tu iPhone).
5. (Opcional) Info → añade `NSPhotoLibraryUsageDescription` = "Para analizar
   tus videos de swing." (PhotosPicker normalmente no lo exige, pero es buena
   práctica.)

## Activar Birdie (caddie AI)

1. Despliega `worker.js` (raíz del repo) en Cloudflare — ver `SETUP-BIRDIE.md`.
   Soporta **Claude o Gemini** según la variable `PROVIDER` del worker.
2. En `Stores.swift` pon la URL del worker:
   ```swift
   static let proxyURL = "https://swinglens-birdie.TUCUENTA.workers.dev"
   ```
3. Listo: el botón "Birdie's deep analysis" mandará los 4 checkpoints + métricas.

## Correr

- Conecta tu iPhone, selecciónalo como destino y dale ▶︎.
- En la app: Subir swing → elige ángulo y bastón → elige un video de la galería
  → verás el análisis y el reporte.

## Ícono de la app (verde)

En el repo está `ios/AppIcon-1024.png` (1024×1024).
1. En Xcode abre **Assets.xcassets** → **AppIcon**.
2. Arrastra `AppIcon-1024.png` al slot grande (1024 / "Any Appearance").
   (Xcode 14+ acepta un solo tamaño de 1024 y genera el resto.)
3. Run: el ícono verde aparece en la pantalla de inicio.

## Cargar un video para probar

- **Simulador:** no trae videos. Arrastra un .mp4/.mov a la ventana del
  simulador (se guarda en Fotos) y luego elígelo en "Subir swing".
- **iPhone real:** usa tus propios videos directamente.

## Qué falta (siguientes milestones)

- Grabar con la cámara dentro de la app (ahora solo galería).
- Overlay del esqueleto en vivo y ajuste manual de checkpoints (scrub), como en
  la web.
- Pulir el diseño a pixel-perfect y animaciones.
- Gating real de suscripción (StoreKit) + estado Pro en servidor.
