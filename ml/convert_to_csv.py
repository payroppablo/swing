#!/usr/bin/env python3
"""
SwingLens — convierte las muestras exportadas (swinglens_training.jsonl) a un
CSV listo para Create ML (Tabular Classification).

Normaliza la pose para que sea invariante a posición y tamaño:
  - origen = centro de caderas
  - escala = ancho de hombros
así un golfista cerca o lejos produce las mismas features.

Uso:
    python3 convert_to_csv.py swinglens_training.jsonl swinglens_pose.csv
    # opcional, solo muestras verificadas por el usuario:
    python3 convert_to_csv.py swinglens_training.jsonl out.csv --corrected-only
"""
import json, sys, csv, math

JOINTS = ["nose", "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
          "left_wrist", "right_wrist", "left_hip", "right_hip",
          "left_knee", "right_knee", "left_ankle", "right_ankle"]

def normalize(kp):
    def get(n):
        v = kp.get(n)
        return (v[0], v[1]) if v else None
    ls, rs = get("left_shoulder"), get("right_shoulder")
    lh, rh = get("left_hip"), get("right_hip")
    if not (ls and rs and lh and rh):
        return None
    cx = (lh[0] + rh[0]) / 2.0
    cy = (lh[1] + rh[1]) / 2.0
    scale = math.hypot(ls[0] - rs[0], ls[1] - rs[1])
    if scale < 1e-3:
        return None
    feats = {}
    for j in JOINTS:
        v = get(j)
        if v:
            feats[j + "_x"] = round((v[0] - cx) / scale, 4)
            feats[j + "_y"] = round((v[1] - cy) / scale, 4)
        else:
            feats[j + "_x"] = 0.0
            feats[j + "_y"] = 0.0
    return feats

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    src, dst = sys.argv[1], sys.argv[2]
    corrected_only = "--corrected-only" in sys.argv

    cols = [j + a for j in JOINTS for a in ("_x", "_y")] + ["checkpoint"]
    rows, skipped = [], 0
    with open(src) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                s = json.loads(line)
            except json.JSONDecodeError:
                continue
            if corrected_only and s.get("source") != "corrected":
                continue
            feats = normalize(s.get("keypoints", {}))
            if not feats:
                skipped += 1
                continue
            feats["checkpoint"] = s.get("checkpoint", "")
            rows.append(feats)

    with open(dst, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)

    print(f"Escritas {len(rows)} filas a {dst}  (saltadas {skipped} sin hombros/caderas)")
    # Resumen por clase
    from collections import Counter
    c = Counter(r["checkpoint"] for r in rows)
    for k, v in sorted(c.items()):
        print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
