# Bagi Tagihan — Implementasi CRNN dan LLM pada Aplikasi Pembagi Tagihan Otomatis

**Daud Aldo Santoso — 223400019**
Universitas Katolik Darma Cendika, 2026

## Tentang Proyek
Aplikasi pembagi tagihan otomatis berbasis foto nota untuk Android dan iOS.
Pipeline: Foto nota → Pra-pemrosesan citra → CRNN (baca teks) → T5 (strukturkan data) → Kalkulasi tagihan → Flutter

## Struktur Repository
- `backend/` — Kode server FastAPI (CRNN + T5 + Redis)
- `flutter_app/` — Kode aplikasi Android & iOS
- `notebooks/` — Notebook Google Colab untuk pelatihan model

## Cara Menjalankan

### Backend
1. Install dependencies:
   pip install -r backend/requirements.txt
2. Jalankan server:
   uvicorn backend.main:app --reload
3. Atau akses langsung di:
   https://pipluptine-bagi-tagihan-api.hf.space

### Flutter App
1. Install Flutter: https://flutter.dev
2. Masuk ke folder flutter_app:
   cd flutter_app
3. Install dependencies:
   flutter pub get
4. Jalankan di emulator atau HP:
   flutter run

### Notebooks (Google Colab)
1. Upload file .ipynb ke Google Colab
2. Mount Google Drive
3. Ikuti instruksi di setiap cell

## Model yang Digunakan
- CRNN: dilatih dari awal, WAR 89.7%, CER 4.12%
- T5-small: fine-tuning mandiri, F1-Score 88.0%
- Format deployment: OpenVINO (.xml + .bin)

## Live Demo
- API: https://pipluptine-bagi-tagihan-api.hf.space/docs
- Aplikasi: https://pipluptiny.itch.io/bagi
- Landing page: https://bagitagihan.netlify.app

## Tech Stack
- Flutter + Dart (frontend Android & iOS)
- FastAPI + Python (backend)
- CRNN + OpenVINO (OCR)
- T5-small (text structuring)
- Redis Upstash (session storage)
- Hugging Face Spaces (deployment)
