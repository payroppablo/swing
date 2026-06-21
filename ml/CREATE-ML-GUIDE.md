# SwingLens — Entrenar el detector de fases con Create ML

Objetivo: entrenar un modelo que, dada la **pose de un frame**, diga qué
checkpoint es (**address / top / impact / finish**). Luego lo metemos como
Core ML para mejorar (o validar) la detección automática.

Tipo de modelo: **Tabular Classification** (clasificador tabular).

## 0. Junta datos
En la app: analiza varios swings y **ajusta los checkpoints** cuando estén mal
(eso genera muestras "corrected", las más valiosas). Cada análisis también
guarda 4 muestras "auto".
- Meta inicial: **150–300 filas** (≈ 40-70 swings). Más es mejor.
- En **Tu progreso → Exportar datos** mándate el archivo
  `swinglens_training.jsonl` a tu Mac (AirDrop/correo).

## 1. Convierte a CSV
En la Mac, en la carpeta `ml/`:
```bash
python3 convert_to_csv.py swinglens_training.jsonl swinglens_pose.csv
# (opcional) solo las verificadas por ti:
python3 convert_to_csv.py swinglens_training.jsonl solo_corregidas.csv --corrected-only
```
Esto normaliza la pose (centro de caderas + ancho de hombros) para que sea
invariante a distancia/tamaño. Te imprime cuántas filas por clase.

## 2. Entrena en Create ML
1. Abre **Xcode → Open Developer Tool → Create ML**.
2. **New Document → Tabular Classification → Next**, nómbralo `SwingPhase`.
3. **Training Data:** arrastra `swinglens_pose.csv`.
4. **Target:** elige la columna **`checkpoint`**.
5. **Features:** deja seleccionadas TODAS las demás columnas (las `_x`/`_y`).
6. (Opcional) Algorithm: deja el automático, o prueba **Boosted Tree**.
7. Pulsa **Train**.
8. Revisa **Evaluation**: fíjate en la *accuracy*. Con pocos datos puede ser
   baja; sube al juntar más. >85% ya es útil.

## 3. Exporta el modelo
- Pestaña **Output → Get** (o arrástralo) → obtienes **`SwingPhase.mlmodel`**.

## 4. Mándamelo / intégralo
- Pásame el `SwingPhase.mlmodel` (o súbelo al repo en `ios/SwingLens/`).
- Yo lo integro: la app correrá el modelo sobre cada frame, sacará la
  probabilidad de "top/impact/…" y **refinará la detección** (elige el frame
  con mayor probabilidad dentro de cada ventana). El esqueleto/normalización
  ya están iguales que en el script, así que encaja directo.

## Notas
- El modelo NO reemplaza a Vision: Vision saca la pose, el modelo clasifica.
- Reentrenas cuando juntes más datos y mandas un update con el nuevo `.mlmodel`.
- Para clasificar **errores** (over-the-top, early extension, sway) repetimos
  el mismo flujo etiquetando por error en vez de por fase — cuando quieras.
