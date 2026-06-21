# SwingLens — App nativa iOS (SwiftUI + Vision)

Milestone 1: flujo completo nativo — elegir video → análisis de pose con
**Vision** (Apple) → checkpoints + plano/postura + métricas → resultados +
progreso + Birdie (vía el Cloudflare Worker). La extracción de frames usa
`AVAssetImageGenerator` (exacta en iOS, sin el problema de seek de Safari).

## Abrir el proyecto (ya armado) — RECOMENDADO

Requiere **Xcode 16 o 17** (usa carpetas sincronizadas).

1. **Clona o baja el repo** en tu Mac.
   - Terminal: `git clone https://github.com/payroppablo/swing.git`
   - (o Code → Download ZIP y descomprime)
2. Abre **`ios/SwingLens.xcodeproj`** (doble clic).
3. **Agrega tu cuenta de Apple (una sola vez):**
   - Menú **Xcode → Settings…** (`Cmd + ,`) → pestaña **Accounts** → botón **+** →
     **Apple ID** → inicia sesión con tu Apple ID (la cuenta gratis sirve).
   - Esto crea tu "Personal Team".
4. **Firma la app:**
   - En el navegador izquierdo, clic en el ícono azul **SwingLens** (arriba).
   - Selecciona el target **SwingLens** → pestaña **Signing & Capabilities**.
   - Marca **Automatically manage signing**.
   - En **Team** elige tu nombre (Personal Team).
   - Si sale error de **Bundle Identifier** ("not available"), cambia
     `com.payroppablo.swinglens` por algo único, ej. `com.tunombre.swinglens1`.
5. **Corre:** arriba elige un **iPhone 16/17 (Simulator)** o tu iPhone real → ▶︎.
   - En iPhone real, primera vez: **Ajustes → General → VPN y gestión de
     dispositivos** → toca tu perfil → **Confiar**.

### Actualizar a futuro
Solo `git pull` (o baja el ZIP de nuevo). Como el proyecto usa carpetas
sincronizadas, **los archivos cambiados se toman solos** — no reemplazas nada a
mano. Cierra y reabre Xcode si no los ve al instante.

## (Alternativa) Crear el proyecto a mano
Solo si tu Xcode es viejo (<16): File → New → Project → iOS App (SwiftUI,
iOS 16+), borra `ContentView.swift`/`<Nombre>App.swift`, y arrastra los 7
`.swift` de `ios/SwingLens/` + `Assets.xcassets`.

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
