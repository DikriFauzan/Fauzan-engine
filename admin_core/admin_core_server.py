from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging

# Konfigurasi logging dasar
logging.basicConfig(level=logging.INFO)

# Inisialisasi aplikasi FastAPI
app = FastAPI(title="Fauzan Engine AI Core Placeholder")

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

# --- Endpoint Agen ---

@app.get("/")
async def root():
    """Endpoint dasar untuk verifikasi server berjalan."""
    return {"message": "Fauzan Engine AI Core is running (Placeholder Mode)."}

@app.post("/api/command_agent/process")
async def process_command(request: CommandRequest):
    """
    Menangani permintaan dari CommandAgent Godot.
    Mengembalikan respon sukses placeholder.
    """
    logging.info(f"[COMMAND] Received command from {request.agent_id}: {request.command}")

    # Logika Placeholder:
    response_data = {"status": "success", "result": f"Command '{request.command}' received and processed by placeholder."}
    
    return response_data

@app.post("/api/economy_agent/sync")
async def sync_economy(request: EconomyRequest):
    """
    Menangani permintaan sinkronisasi dari EconomyAgent Godot.
    Mengembalikan data placeholder yang dibutuhkan oleh EconomyAgent, terutama harga pasar.
    """
    logging.info(f"[ECONOMY] Received economy sync from {request.agent_id} for action: {request.action}")

    # Data KRITIS yang dicari oleh EconomyAgent (current_market_prices)
    if request.action == "get_initial_data":
        # Data placeholder ini harus cocok dengan ekspektasi Godot agar tidak error
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

# --- Endpoint Kesehatan/Verifikasi ---

@app.get("/health")
async def health_check():
    """Endpoint untuk Godot memverifikasi koneksi."""
    return {"status": "ok", "service": "AI_CORE_API", "version": "1.0-placeholder"}
