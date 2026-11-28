
from ultralytics import YOLO
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
import html
import webbrowser
from typing import Protocol, cast


class YOLOLayer(Protocol):
    f: object
    type: str
    np: int


class YOLODetectionModel(Protocol):
    model: Iterable[YOLOLayer]
    yaml: Mapping[str, object]


class YOLOModel(Protocol):
    model: YOLODetectionModel

# ==========================================
# LOKASI MODEL EDUSENSE
# ==========================================

SCRIPT_DIR = Path(__file__).resolve().parent

if SCRIPT_DIR.name.lower() == "backend":
    PROJECT_DIR = SCRIPT_DIR.parent
else:
    PROJECT_DIR = SCRIPT_DIR

MODEL_PATH = PROJECT_DIR / "backend" / "models" / "best.pt"
OUTPUT_PATH = PROJECT_DIR / "arsitektur_edusense.html"

# ==========================================
# LOAD MODEL ASLI
# ==========================================

model = cast(YOLOModel, YOLO(str(MODEL_PATH)))
layers = model.model.model
config = model.model.yaml

backbone_config = cast(
    Sequence[Sequence[object]],
    config.get("backbone", [])
)
head_config = cast(
    Sequence[Sequence[object]],
    config.get("head", [])
)

jumlah_backbone = len(backbone_config)

# ==========================================
# IDENTIFIKASI BACKBONE, NECK, DAN HEAD
# ==========================================

data = []

for i, layer in enumerate(layers):

    if i < jumlah_backbone:
        bagian = "Backbone"

    elif "Detect" in layer.type:
        bagian = "Head"

    else:
        bagian = "Neck"

    if i < jumlah_backbone:
        konfigurasi = backbone_config[i]
    else:
        index_head = i - jumlah_backbone

        if index_head < len(head_config):
            konfigurasi = head_config[index_head]
        else:
            konfigurasi = []

    from_layer = str(layer.f)

    repeats = (
        konfigurasi[1]
        if len(konfigurasi) > 1
        else "-"
    )

    args = (
        str(konfigurasi[3])
        if len(konfigurasi) > 3
        else "-"
    )

    data.append({
        "bagian": bagian,
        "layer": i,
        "from": from_layer,
        "module": layer.type,
        "repeats": repeats,
        "parameters": layer.np,
        "args": args
    })

# ==========================================
# MEMBUAT ISI TABEL
# ==========================================

rows = ""

bagian_sebelumnya = None

for item in data:

    if item["bagian"] != bagian_sebelumnya:

        rows += f"""
        <tr class="section">
            <td colspan="7">{item['bagian'].upper()}</td>
        </tr>
        """

        bagian_sebelumnya = item["bagian"]

    rows += f"""
    <tr>
        <td>{item['layer']}</td>
        <td>{html.escape(item['from'])}</td>
        <td>{html.escape(item['module'])}</td>
        <td>{item['repeats']}</td>
        <td>{item['parameters']:,}</td>
        <td>{html.escape(item['args'])}</td>
        <td>{item['bagian']}</td>
    </tr>
    """

# ==========================================
# HTML TABEL ARSITEKTUR EDUSENSE
# ==========================================

html_content = f"""
<!DOCTYPE html>
<html lang="id">

<head>

<meta charset="UTF-8">

<title>Arsitektur YOLOv8 EduSense</title>

<style>

body {{
    font-family: Arial, sans-serif;
    background: #ffffff;
    color: #222222;
    padding: 25px;
}}

h1 {{
    text-align: center;
    margin-bottom: 25px;
}}

table {{
    width: 100%;
    border-collapse: collapse;
}}

th {{
    background: #1e40af;
    color: white;
    padding: 12px;
    border: 1px solid #cccccc;
}}

td {{
    padding: 10px;
    border: 1px solid #cccccc;
    text-align: center;
}}

.section td {{
    background: #dbeafe;
    color: #1e3a8a;
    font-weight: bold;
    text-align: left;
    font-size: 16px;
}}

tr:nth-child(even):not(.section) {{
    background: #f8fafc;
}}

</style>

</head>

<body>

<h1>ARSITEKTUR YOLOv8 SISTEM EDUSENSE</h1>

<table>

<thead>
<tr>
    <th>Layer</th>
    <th>From</th>
    <th>Module</th>
    <th>Repeats</th>
    <th>Parameters</th>
    <th>Arguments</th>
    <th>Bagian Arsitektur</th>
</tr>
</thead>

<tbody>

{rows}

</tbody>

</table>

</body>

</html>
"""

# ==========================================
# SIMPAN DAN BUKA TABEL
# ==========================================

OUTPUT_PATH.write_text(
    html_content,
    encoding="utf-8"
)

webbrowser.open(OUTPUT_PATH.as_uri())
