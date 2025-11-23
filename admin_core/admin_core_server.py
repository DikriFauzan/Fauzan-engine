from fastapi import FastAPI, HTTPException, Request, status, Response
from pydantic import BaseModel
import logging
import os 
import json 

# --- KONFIGURASI ---
# Setel token verifikasi di sini. Gunakan token yang sama yang Anda masukkan ke Meta.
VERIFY_TOKEN = "NEO_WA_2025" 

# Konfigurasi logging dasar
logging.basicConfig(level=logging.INFO)

# Inisialisasi aplikasi FastAPI
app = FastAPI(title="Fauzan Engine AI Core (WhatsApp Ready)")

# --- Skema Data (Untuk Menangani Permintaan Godot) ---

# Skema data yang akan diterima dari CommandAgent
class CommandRequest(BaseModel):
    agent_id: str
    command: str
    data: dict = {}

# Skema data yang akan diterima dari EconomyAgent
class EconomyRequest(BaseModel):
    agent_id: str
    market_data: dict
    action: str

# --- Endpoint AGEN Godot (Kode Lama Anda) ---

@app.get("/")
async def root():
    """Endpoint dasar untuk verifikasi server berjalan."""
    return {"message": "Fauzan Engine AI Core is running (WhatsApp Ready)."}

@app.post("/api/command_agent/process")
async def process_command(request: CommandRequest):
    """Menangani permintaan dari CommandAgent Godot."""
    logging.info(f"[COMMAND] Received command from {request.agent_id}: {request.command}")
    response_data = {"status": "success", "result": f"Command '{request.command}' received and processed by placeholder."}
    return response_data

@app.post("/api/economy_agent/sync")
async def sync_economy(request: EconomyRequest):
    """Menangani permintaan sinkronisasi dari EconomyAgent Godot."""
    logging.info(f"[ECONOMY] Received economy sync from {request.agent_id} for action: {request.action}")

    if request.action == "get_initial_data":
        return {
            "status": "success",
            "current_market_prices": {
                "corn": 10.5,
                "gold": 1500.0,
                "oil": 80.0
            },
            "stock_volume": 10000
        }
    
    return {"status": "success", "economy_update": "data accepted"}

# --- Endpoint WEBHOOK WHATSAPP (BARU) ---

@app.get("/webhook/whatsapp")
async def verify_webhook(request: Request):
    """
    1. Verifikasi Token Webhook Meta (GET request).
       Endpoint ini dipanggil oleh Meta saat Anda menekan tombol 'Verify and Save'.
    """
    try:
        # Mengambil parameter dari URL
        mode = request.query_params.get("hub.mode")
        token = request.query_params.get("hub.verify_token")
        challenge = request.query_params.get("hub.challenge")

        if mode and token:
            if mode == "subscribe" and token == VERIFY_TOKEN:
                logging.info(f"[WHATSAPP] Verified subscription. Challenge: {challenge}")
                # Mengembalikan challenge untuk verifikasi sukses (Wajib 200 OK)
                return Response(content=challenge, media_type="text/plain", status_code=200)
            else:
                logging.warning("[WHATSAPP] Token mismatch or mode not subscribe.")
                # Token tidak cocok atau mode salah
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verification failed")
        else:
            logging.warning("[WHATSAPP] Missing mode or token in request.")
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing parameters")

    except Exception as e:
        logging.error(f"[WHATSAPP] Verification error: {e}")
        # Gunakan HTTP 500 jika ada masalah server
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Server error during verification")


@app.post("/webhook/whatsapp")
async def receive_webhook(request: Request):
    """
    2. Menerima notifikasi atau pesan WhatsApp (POST request).
    """
    try:
        data = await request.json()
        logging.info(f"[WHATSAPP] Received data:\n{json.dumps(data, indent=2)}")

        # Logika Placeholder: 
        # Di sini Anda akan mengurai pesan dan memicu respons jika diperlukan.
        
        # Harus selalu mengembalikan status 200 OK ke Meta dalam waktu 20 detik
        return {"status": "ok"}
        
    except Exception as e:
        logging.error(f"[WHATSAPP] Error processing webhook data: {e}")
        # Tetap kembalikan 200 OK agar Meta tidak terus mengirim ulang
        return {"status": "error", "message": "Failed to process data"}, status.HTTP_200_OK

# --- Endpoint Kesehatan/Verifikasi ---

@app.get("/health")
async def health_check():
    """Endpoint untuk Godot memverifikasi koneksi."""
    return {"status": "ok", "service": "AI_CORE_API", "version": "1.0-whatsapp-ready"}

# Bagian ini penting jika Anda menjalankannya tanpa `python -m uvicorn ...`
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
