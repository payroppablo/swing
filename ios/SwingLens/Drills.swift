import SwiftUI

// Un ejercicio con objetivo, cómo sentirlo (cues) y dosis.
struct DrillInfo: Identifiable {
    let id = UUID()
    let name: String
    let goal: String
    let feel: String      // cómo sentirlo
    let dose: String
}

// Librería por área. Cadera con varios ejercicios (lo que pediste).
enum DrillLibrary {
    static let byArea: [(key: String, area: String, drills: [DrillInfo])] = [
        ("hip", "Cadera (rotación y potencia)", [
            DrillInfo(name: "Pump-and-Hold",
                      goal: "Que las caderas LIDEREN la bajada (no las manos).",
                      feel: "A mitad del backswing, baja a la mitad y PARA. Siente cómo el peso pasa al pie delantero y la cadera delantera empieza a abrir hacia el objetivo ANTES de soltar las manos. Repite el 'pump' 2 veces y al 3º pega.",
                      dose: "3 series · 8 reps · 5 min"),
            DrillInfo(name: "Sentarse al impacto (chair drill)",
                      goal: "Rotación con estabilidad, sin perder altura.",
                      feel: "Pon una silla/banco alto tocando tu cadera trasera. En el backswing el glúteo trasero toca la silla; en la bajada el glúteo delantero la toca. Sientes que GIRAS sentado, no que te paras.",
                      dose: "3 series · 10 reps · 5 min"),
            DrillInfo(name: "Banda/toalla en la cadera (separación)",
                      goal: "Crear X-factor: cadera adelanta, torso espera.",
                      feel: "Una banda (o que alguien jale una toalla) tira de tu cadera delantera hacia el objetivo al bajar. Siente que la cadera arranca primero y los hombros llegan después: ahí está el lag y la potencia.",
                      dose: "3 series · 8 reps · 6 min"),
            DrillInfo(name: "Step-through (paso al finish)",
                      goal: "Transferir peso completo y rotar hasta el final.",
                      feel: "Al terminar, deja que el pie trasero dé un paso hacia adelante. Sientes la cadera girar del todo y el peso 100% en el lado delantero.",
                      dose: "2 series · 8 reps · 4 min"),
        ]),
        ("head", "Estabilidad de cabeza", [
            DrillInfo(name: "Cabeza en la pared",
                      goal: "Mantener el centro y no irte hacia el objetivo.",
                      feel: "En address apoya suave la frente/coronilla en una pared. Haz el backswing manteniendo el contacto: sientes que giras alrededor de un eje fijo.",
                      dose: "3 series · 10 reps · 6 min"),
            DrillInfo(name: "Mirada fija al punto",
                      goal: "Quietud de cabeza hasta después del golpe.",
                      feel: "Fija la vista en un punto detrás de la bola y NO lo sueltes hasta oír/sentir el impacto. La cabeza se queda; los brazos se van.",
                      dose: "3 series · 10 reps · 4 min"),
        ]),
        ("tempo", "Tempo y ritmo", [
            DrillInfo(name: "Cuenta 1-2-3",
                      goal: "Grabar el ratio ~3:1 backswing/bajada.",
                      feel: "Cuenta '1-2' suave subiendo y '3' bajando. La bajada es más rápida pero NO brusca; siente que la transición es fluida, sin tirón desde arriba.",
                      dose: "3 series · 10 swings · 5 min"),
            DrillInfo(name: "Pies juntos",
                      goal: "Ritmo y balance sin usar fuerza de más.",
                      feel: "Junta los pies y haz medios swings. Si pierdes el balance, vas muy rápido o muy fuerte: suaviza hasta sentirte estable.",
                      dose: "2 series · 12 swings · 4 min"),
        ]),
        ("setup", "Setup y postura", [
            DrillInfo(name: "Chequeo al espejo",
                      goal: "Columna neutra y hombros nivelados.",
                      feel: "Frente a un espejo, inclínate desde la cadera (no encorvando la espalda) y deja los brazos colgar. Siente la espalda recta y el peso en el medio del pie.",
                      dose: "2 series · 8 reps · 4 min"),
        ]),
        ("ft", "Follow-through / Finish", [
            DrillInfo(name: "Sostén el finish 3 seg",
                      goal: "Terminación balanceada y repetible.",
                      feel: "Llega a un finish completo (pecho al objetivo, peso delantero) y CONGÉLALO 3 segundos. Si te tambaleas, ajusta hasta quedar firme.",
                      dose: "3 series · 8 reps · 5 min"),
        ]),
    ]

    static func areaTitle(_ key: String) -> String {
        byArea.first { $0.key == key }?.area ?? key
    }
}

struct DrillsView: View {
    @EnvironmentObject var s: AppState

    // Si hay un análisis, priorizamos el área más débil
    var weakestKey: String? {
        guard let r = s.result else { return nil }
        let scores: [(String, Int)] = [
            ("hip", r.hipRotation), ("head", r.headStability), ("tempo", r.tempo),
            ("setup", r.setup), ("ft", r.followThrough)
        ]
        return scores.min { $0.1 < $1.1 }?.0
    }

    var ordered: [(key: String, area: String, drills: [DrillInfo])] {
        guard let w = weakestKey else { return DrillLibrary.byArea }
        return DrillLibrary.byArea.sorted { ($0.key == w ? 0 : 1) < ($1.key == w ? 0 : 1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                backRow { s.screen = .home }
                Text("DRILLS & TIPS").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundColor(Theme.actionGreen)
                Text("Ejercicios para sentir y mejorar").font(Theme.serif(28)).foregroundColor(Theme.ink)
                if let w = weakestKey {
                    Text("Empezamos por tu área más floja: \(DrillLibrary.areaTitle(w)).")
                        .font(.system(size: 13)).foregroundColor(Theme.slate)
                }

                ForEach(ordered, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(group.area.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.5).foregroundColor(Color(hex: 0x9AA39C))
                            if group.key == weakestKey {
                                Text("PRIORIDAD").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.amber)
                                    .padding(.horizontal, 7).padding(.vertical, 2).background(Color(hex: 0xF5EFE0)).cornerRadius(99)
                            }
                        }
                        ForEach(group.drills) { d in drillCard(d, highlight: group.key == weakestKey) }
                    }
                }
            }
            .padding(20).padding(.top, 30)
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    func drillCard(_ d: DrillInfo, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d.name).font(Theme.serif(19)).foregroundColor(highlight ? .white : Theme.ink)
            label("OBJETIVO", d.goal, highlight: highlight)
            label("CÓMO SENTIRLO", d.feel, highlight: highlight)
            Text(d.dose).font(Theme.mono(11)).foregroundColor(highlight ? .white.opacity(0.7) : Color(hex: 0x9AA39C))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(highlight ? AnyView(LinearGradient(colors: [Theme.darkGreen, Color(hex: 0x10301F)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(Color.white))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(highlight ? Color.clear : Theme.cardBorder))
    }

    func label(_ tag: String, _ text: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tag).font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(highlight ? Theme.lightGreen : Color(hex: 0x3E8F58))
            Text(text).font(.system(size: 13)).foregroundColor(highlight ? .white.opacity(0.9) : Theme.slate).fixedSize(horizontal: false, vertical: true)
        }
    }
}
