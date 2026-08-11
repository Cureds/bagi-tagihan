import os, io, re, json, httpx, tempfile, subprocess, uuid
from fastapi import FastAPI, File, UploadFile, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.concurrency import run_in_threadpool
from PIL import Image, ImageOps
import numpy as np
from dotenv import load_dotenv
from typing import Optional

load_dotenv()

UPSTASH_URL   = os.getenv("UPSTASH_REDIS_REST_URL",   "https://square-squid-142339.upstash.io")
UPSTASH_TOKEN = os.getenv("UPSTASH_REDIS_REST_TOKEN", "gQAAAAAAAiwDAAIgcDI2ODRhM2ZhYTgyMmY0NGZkODZjYWY4YjkwYmQ4YjhiZA")

PARSER_REPO   = os.getenv("PARSER_REPO", "pipluptine/bagi-tagihan-parser")
PARSER_PREFIX = "ekstrak nota: "

app = FastAPI(
    title="Bagi Tagihan API", version="2.0.0",
    description="Backend Bagi Tagihan — CRAFT + CRNN + T5 (self-hosted) + WebSocket",
    contact={"name": "Daud Aldo Santoso"},
)

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── Redis helpers ─────────────────────────────────────────────────
async def redis_set(key: str, value: dict, ex: int = 21600):
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                UPSTASH_URL,
                headers={"Authorization": f"Bearer {UPSTASH_TOKEN}", "Content-Type": "application/json"},
                json=["SET", key, json.dumps(value), "EX", ex],
            )
            print(f"Redis SET {key}: {resp.json()}")
    except Exception as e:
        print(f"Redis SET error: {e}")

async def redis_get(key: str) -> Optional[dict]:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                UPSTASH_URL,
                headers={"Authorization": f"Bearer {UPSTASH_TOKEN}", "Content-Type": "application/json"},
                json=["GET", key],
            )
            result = resp.json().get("result")
            if result is None:
                return None
            return json.loads(result)
    except Exception as e:
        print(f"Redis GET error: {e}")
        return None

async def redis_delete(key: str):
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(
                UPSTASH_URL,
                headers={"Authorization": f"Bearer {UPSTASH_TOKEN}", "Content-Type": "application/json"},
                json=["DEL", key],
            )
    except Exception as e:
        print(f"Redis DEL error: {e}")

def room_key(code: str) -> str:
    return f"room:{code}"

# ── WebSocket manager ─────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.rooms: dict = {}

    async def connect(self, websocket: WebSocket, room_code: str):
        await websocket.accept()
        if room_code not in self.rooms:
            self.rooms[room_code] = []
        self.rooms[room_code].append(websocket)

    def disconnect(self, websocket: WebSocket, room_code: str):
        if room_code in self.rooms:
            if websocket in self.rooms[room_code]:
                self.rooms[room_code].remove(websocket)
            if not self.rooms[room_code]:
                del self.rooms[room_code]

    async def broadcast(self, room_code: str, message: dict):
        if room_code not in self.rooms:
            return
        disconnected = []
        for ws in self.rooms[room_code]:
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.append(ws)
        for ws in disconnected:
            if ws in self.rooms.get(room_code, []):
                self.rooms[room_code].remove(ws)

manager = ConnectionManager()

# ══════════════════════════════════════════════════════════════════
#  AI PIPELINE: CRAFT (deteksi) → CRNN (baca) → T5 (strukturkan)
# ══════════════════════════════════════════════════════════════════

# ── CRNN (OpenVINO) ───────────────────────────────────────────────
# Charset BARU (uppercase-only) — harus sama persis dengan training CRNN v2
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ .,:-/()%&"
BLANK = 0   # CTC blank di index 0

def idx_to_char(i):
    # index 1..len(CHARS) -> karakter; 0 = blank
    return CHARS[i-1] if 1 <= i <= len(CHARS) else ''

compiled_model = None      # CRNN OpenVINO
reader         = None      # EasyOCR (detektor CRAFT)
parser_tok     = None      # T5 tokenizer
parser_model   = None      # T5 model

def load_models():
    global compiled_model, reader, parser_tok, parser_model
    # 1) CRNN OpenVINO
    try:
        from openvino import Core
        ie = Core()
        compiled_model = ie.compile_model(ie.read_model("models/crnn_model.xml"), "CPU")
        print("CRNN (OpenVINO) loaded!")
    except Exception as e:
        print(f"CRNN load failed: {e}")
    # 2) EasyOCR detektor (CRAFT)
    try:
        import easyocr
        reader = easyocr.Reader(['en'], gpu=False)
        print("EasyOCR (CRAFT detector) loaded!")
    except Exception as e:
        print(f"EasyOCR load failed: {e}")
    # 3) T5 parser
    try:
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        parser_tok   = AutoTokenizer.from_pretrained(PARSER_REPO)
        parser_model = AutoModelForSeq2SeqLM.from_pretrained(PARSER_REPO).eval()
        print(f"T5 parser loaded from {PARSER_REPO}!")
    except Exception as e:
        print(f"T5 parser load failed: {e}")

@app.on_event("startup")
async def startup():
    load_models()

# ── CRNN baca SATU baris/crop ─────────────────────────────────────
def decode_crnn(image):
    if compiled_model is None:
        return ""
    try:
        img = image.convert('L').resize((384, 32), Image.LANCZOS)   # 384 lebar (model v2)
        arr = np.array(img, dtype=np.float32)
        arr = (arr / 255.0 - 0.5) / 0.5
        arr = arr[np.newaxis, np.newaxis, :, :]
        req = compiled_model.create_infer_request()
        req.infer({compiled_model.input(0): arr})
        out = req.get_output_tensor(0).data        # (1, T, num_classes)
        idx = np.argmax(out[0], axis=1)            # argmax per timestep
        chars, prev = [], BLANK
        for i in idx:
            i = int(i)
            if i != BLANK and i != prev:
                chars.append(idx_to_char(i))
            prev = i
        return ''.join(chars).strip()
    except Exception as e:
        print(f"CRNN error: {e}")
        return ""

# ── CRAFT deteksi baris → CRNN baca tiap sel ──────────────────────
def ocr_receipt(pil):
    if reader is None:
        return ""
    arr = np.array(pil.convert('RGB'))
    horizontal, _ = reader.detect(arr, width_ths=0.7, ycenter_ths=0.5)
    boxes = sorted(horizontal[0], key=lambda b: (b[2], b[0]))
    lines, cur, cur_y = [], [], None
    for b in boxes:
        x1, x2, y1, y2 = b
        yc = (y1 + y2) / 2
        if cur_y is None or abs(yc - cur_y) < max(8, (y2 - y1) * 0.6):
            cur.append(b)
            cur_y = yc if cur_y is None else (cur_y * len(cur) + yc) / (len(cur) + 1)
        else:
            lines.append(cur); cur = [b]; cur_y = yc
    if cur:
        lines.append(cur)
    gray = np.array(pil.convert('L'))
    out = []
    for line in lines:
        parts = []
        for x1, x2, y1, y2 in sorted(line, key=lambda b: b[0]):
            crop = gray[max(0, int(y1)):int(y2), max(0, int(x1)):int(x2)]
            if crop.size == 0:
                continue
            t = decode_crnn(Image.fromarray(crop)).strip()
            if t:
                parts.append(t)
        if parts:
            out.append(" ".join(parts))
    return "\n".join(out)

# ── T5 parser ─────────────────────────────────────────────────────
def run_parser(text):
    if parser_model is None:
        return ""
    import torch
    enc = parser_tok(PARSER_PREFIX + text, return_tensors="pt", max_length=768, truncation=True)
    with torch.no_grad():
        out = parser_model.generate(**enc, max_length=512, num_beams=4, early_stopping=True)
    return parser_tok.decode(out[0], skip_special_tokens=True)

# ── Number snapping (koreksi digit ke angka di nota) ──────────────
def _edit_distance(a, b):
    m, n = len(a), len(b)
    dp = list(range(n + 1))
    for i in range(1, m + 1):
        prev = dp[0]; dp[0] = i
        for j in range(1, n + 1):
            cur = dp[j]
            dp[j] = min(dp[j] + 1, dp[j - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = cur
    return dp[n]

_LOOKALIKE = str.maketrans({'O': '0', 'o': '0', 'Q': '0', 'I': '1', 'l': '1',
                            'S': '5', 's': '5', 'B': '8', 'G': '6', 'Z': '2'})

def input_numbers(text):
    clean = text.translate(_LOOKALIKE)
    nums = set()
    for m in re.finditer(r'\d[\d.,]*', clean):
        d = re.sub(r'\D', '', m.group())
        if d and int(d) >= 1000:
            nums.add(int(d))
    return nums

def snap(pred, inums):
    if pred < 1000 or pred in inums or not inums:
        return pred
    ps = str(pred); best = None; bd = 99
    for x in inums:
        xs = str(x)
        if abs(len(xs) - len(ps)) > 1:
            continue
        d = _edit_distance(ps, xs)
        if d < bd:
            bd = d; best = x
    return best if best is not None and bd <= 2 else pred

# ── Parse output T5 → struktur ────────────────────────────────────
def parse_struct(s):
    items = []
    for m in re.finditer(r"ITEM:\s*(.+?)\s*\|\s*(\d+)\s*\|\s*(\d+)", s):
        items.append([m.group(1).strip(), int(m.group(2)), int(m.group(3))])
    def grab(k):
        mm = re.search(rf"{k}:\s*(\d+)", s)
        return int(mm.group(1)) if mm else 0
    return items, grab("SERVICE"), grab("TAX"), grab("DISCOUNT")

# ── Kategori via keyword (dikerjakan Python) ──────────────────────
MINUMAN_KW = ["tea", "teh", "kopi", "coffee", "jus", "juice", "ice", "es ", "milk", "latte",
              "cappu", "americano", "soda", "cola", "sprite", "lemon", "orange", "water",
              "air ", "wedang", "cendol", "matcha", "dawet", "milo", "float", "mocktail",
              "frappe", "jeruk", "nipis", "lychee", "lyche", "thai", "mango", "manis"]

def classify(name):
    low = " " + name.lower() + " "
    return "minuman" if any(k in low for k in MINUMAN_KW) else "makanan"

# ── Buang baris yang bukan item (subtotal/total/pembayaran/pajak) ──
NON_ITEM_KW = ["subtotal", "sub total", "sub-total", "sb total", "total", "netto",
               "tunai", "cash", "change", "kembali", "pajak", "service",
               "charge", "diskon", "discount", "amount due", "rounding"]

def is_non_item(name):
    low = name.lower()
    return any(kw in low for kw in NON_ITEM_KW)

# ── Pipeline lengkap (dijalankan di threadpool) ───────────────────
def process_receipt(pil):
    ocr = ocr_receipt(pil)
    ocr = re.sub(r'(\d)[.,]00\b', r'\1', ocr)        # normalisasi sen (95,000.00 -> 95000)
    raw = run_parser(ocr) if ocr.strip() else ""
    items, service, tax, discount = parse_struct(raw)
    inums = input_numbers(ocr)
    items = [[nm, snap(lt, inums), q] for nm, lt, q in items]
    service  = snap(service, inums)
    tax      = snap(tax, inums)
    discount = snap(discount, inums)
    return ocr, items, service, tax, discount

def open_image_safe(img_bytes):
    try:
        return Image.open(io.BytesIO(img_bytes)).convert("RGB")
    except Exception:
        with tempfile.NamedTemporaryFile(suffix=".heic", delete=False) as tmp:
            tmp.write(img_bytes)
            tmp_path = tmp.name
        out_path = tmp_path.replace(".heic", ".jpg")
        subprocess.run(["sips", "-s", "format", "jpeg", tmp_path, "--out", out_path])
        return Image.open(out_path).convert("RGB")

# ── WebSocket ─────────────────────────────────────────────────────
@app.websocket("/ws/{room_code}/{participant_id}")
async def websocket_endpoint(websocket: WebSocket, room_code: str, participant_id: str):
    await manager.connect(websocket, room_code)
    try:
        room = await redis_get(room_key(room_code))
        if room:
            await websocket.send_json({"type": "room_state", "data": room})
        while True:
            data = await websocket.receive_json()
            await manager.broadcast(room_code, data)
    except WebSocketDisconnect:
        manager.disconnect(websocket, room_code)
        await manager.broadcast(room_code, {"type": "participant_left", "participant_id": participant_id})

# ── Scan endpoint ─────────────────────────────────────────────────
@app.post("/api/scan-receipt", tags=["OCR"])
async def scan_receipt(image: UploadFile = File(...)):
    img_bytes = await image.read()
    print(f"Scan received: {len(img_bytes)} bytes")
    pil_image = open_image_safe(img_bytes)
    pil_image = ImageOps.exif_transpose(pil_image)
    pil_image.thumbnail((1920, 1920), Image.LANCZOS)
    image_filename = f"{uuid.uuid4()}.jpg"
    image_path     = f"uploads/{image_filename}"
    pil_image.save(image_path, "JPEG", quality=90)
    image_url = f"/uploads/{image_filename}"

    # ── Jalankan pipeline berat di threadpool (biar event loop / WebSocket tidak nge-block) ──
    ocr_text, items, service_amount, tax_amount, discount_amount = await run_in_threadpool(
        process_receipt, pil_image
    )
    print(f"OCR text:\n{ocr_text}")

    # ── Expand qty jadi item per-porsi (shape SAMA seperti versi lama) ──
    # ── Buang baris non-item, TAPI jangan sampai kosong total ──
    candidate = [it for it in items if not is_non_item(it[0])]
    if not candidate and items:
        candidate = items          # safety: mending nama berantakan daripada kosong

    expanded = []
    for name, line_total, qty in candidate:
        qty = max(1, qty)
        per_porsi = line_total // qty if qty else line_total
        category  = classify(name)
        for i in range(qty):
            expanded.append({
                "name":            name if qty == 1 else f"{name} ({i+1}/{qty})",
                "price_in_rupiah": per_porsi,
                "category":        category,
            })

    subtotal     = sum(it["price_in_rupiah"] for it in expanded)
    tax_rate     = round(tax_amount     / subtotal, 4) if subtotal > 0 and tax_amount     > 0 else 0
    service_rate = round(service_amount / subtotal, 4) if subtotal > 0 and service_amount > 0 else 0

    if tax_amount > 0 and service_amount > 0:
        tax_scheme = "service_before_tax"
    elif tax_amount > 0:
        tax_scheme = "tax_only"
    else:
        tax_scheme = "none"

    total_on_receipt = subtotal + service_amount + tax_amount - discount_amount
    print(f"Scan result: {len(expanded)} items, scheme={tax_scheme}")
    return {
        "items":               expanded,
        "tax_scheme":          tax_scheme,
        "tax_rate":            tax_rate,
        "service_rate":        service_rate,
        "tax_amount":          tax_amount,
        "service_amount":      service_amount,
        "discount_amount":     discount_amount,
        "subtotal_on_receipt": subtotal,
        "total_on_receipt":    total_on_receipt,
        "restaurant_name":     "",
        "image_url":           image_url,
        "raw_text":            ocr_text,
        "pipeline":            "craft+crnn+t5+snap",
        "confidence_notes":    "",
    }

# ── Room endpoints ────────────────────────────────────────────────
@app.post("/api/rooms", status_code=201, tags=["Rooms"])
async def create_room(data: dict):
    code = data["room_code"]
    room = {
        "code":            code, "host_id":         data["host_id"],
        "participants":    [{"id": data["host_id"], "name": data["host_name"], "color_index": 0, "is_host": True}],
        "menu_items":      [], "nota_groups":     [], "manual_expenses": [],
        "tax_scheme":      "none", "tax_rate":        0.10,
        "service_rate":    0.05,   "discount_amount": 0,
        "custom_amounts":  {},
    }
    await redis_set(room_key(code), room)
    print(f"Room {code} created and saved to Redis")
    return {"room_code": code}

@app.get("/api/rooms/{code}", tags=["Rooms"])
async def get_room(code: str):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Room tidak ditemukan")
    return room

@app.post("/api/rooms/{code}/join", tags=["Rooms"])
async def join_room(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Kode tidak ditemukan")

    participant_id = data["participant_id"]
    name           = data["name"]

    existing = next(
        (p for p in room["participants"] if p["name"].lower() == name.lower()),
        None
    )

    if existing:
        result_id = existing["id"]
        print(f"Name reconnect: '{name}' reused ID {result_id}")
    else:
        room["participants"].append({
            "id":          participant_id,
            "name":        name,
            "color_index": len(room["participants"]),
            "is_host":     False
        })
        result_id = participant_id

    await redis_set(room_key(code), room)
    await manager.broadcast(code, {"type": "participant_joined", "data": room})

    response = dict(room)
    response["your_participant_id"] = result_id
    return response

@app.post("/api/rooms/{code}/leave", tags=["Rooms"])
async def leave_room(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        return {"status": "ok"}
    participant_id = data["participant_id"]
    room["participants"] = [p for p in room["participants"] if p["id"] != participant_id]
    await redis_set(room_key(code), room)
    await manager.broadcast(code, {"type": "participant_left", "participant_id": participant_id, "data": room})
    print(f"Participant {participant_id} left room {code}")
    return {"status": "ok"}

@app.post("/api/rooms/{code}/sync-items", tags=["Sync"])
async def sync_items(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Room tidak ditemukan")
    room["menu_items"]      = data.get("items", [])
    room["nota_groups"]     = data.get("nota_groups", [])
    room["tax_scheme"]      = data.get("tax_scheme", "none")
    room["tax_rate"]        = data.get("tax_rate", 0.10)
    room["service_rate"]    = data.get("service_rate", 0.05)
    room["discount_amount"] = data.get("discount_amount", 0)
    await redis_set(room_key(code), room)
    await manager.broadcast(code, {"type": "items_updated", "data": {
        "items":           room["menu_items"],
        "nota_groups":     room["nota_groups"],
        "tax_scheme":      room["tax_scheme"],
        "tax_rate":        room["tax_rate"],
        "service_rate":    room["service_rate"],
        "discount_amount": room["discount_amount"],
    }})
    return {"status": "ok"}

@app.post("/api/rooms/{code}/sync-assignment", tags=["Sync"])
async def sync_assignment(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Room tidak ditemukan")
    item_id        = data["item_id"]
    participant_id = data["participant_id"]
    for item in room["menu_items"]:
        if item["id"] == item_id:
            assigned = item.get("assigned_participant_ids", [])
            if participant_id in assigned:
                assigned.remove(participant_id)
            else:
                assigned.append(participant_id)
            item["assigned_participant_ids"] = assigned
            break
    await redis_set(room_key(code), room)
    await manager.broadcast(code, {"type": "items_updated", "data": {
        "items":           room["menu_items"],
        "nota_groups":     room.get("nota_groups", []),
        "tax_scheme":      room.get("tax_scheme", "none"),
        "tax_rate":        room.get("tax_rate", 0.10),
        "service_rate":    room.get("service_rate", 0.05),
        "discount_amount": room.get("discount_amount", 0),
    }})
    return {"status": "ok"}

@app.post("/api/rooms/{code}/sync-expenses", tags=["Sync"])
async def sync_expenses(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Room tidak ditemukan")
    room["manual_expenses"] = data.get("expenses", [])
    await redis_set(room_key(code), room)
    await manager.broadcast(code, {
        "type": "expenses_updated",
        "data": {"manual_expenses": room["manual_expenses"]}
    })
    return {"status": "ok"}

@app.post("/api/rooms/{code}/sync-custom-amounts", tags=["Sync"])
async def sync_custom_amounts(code: str, data: dict):
    room = await redis_get(room_key(code))
    if not room:
        raise HTTPException(404, "Room tidak ditemukan")
    room["custom_amounts"] = data.get("amounts", {})
    await redis_set(room_key(code), room)
    await manager.broadcast(code, {
        "type": "amounts_updated",
        "data": {"custom_amounts": room["custom_amounts"]}
    })
    return {"status": "ok"}

@app.get("/", tags=["Status"])
async def root():
    return {"app": "Bagi Tagihan API", "version": "2.0.0", "status": "running",
            "crnn_loaded":   compiled_model is not None,
            "craft_loaded":  reader is not None,
            "parser_loaded": parser_model is not None,
            "docs": "/docs"}

@app.get("/status", tags=["Status"])
async def status():
    return {"status": "running",
            "crnn":   "loaded" if compiled_model is not None else "not loaded",
            "craft":  "loaded" if reader is not None else "not loaded",
            "parser": "loaded" if parser_model is not None else "not loaded"}
