# ai-engine/app/main.py
# FastAPI AI Engine for FlowPath — GreenWave Optimization & Traffic Prediction

import os
import logging
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.security.api_key import APIKeyHeader
from contextlib import asynccontextmanager

from app.routers import prediction, optimization

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("flowpath.ai")

# ── Startup / Shutdown ───────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 FlowPath AI Engine starting up")
    logger.info(f"   Environment: {os.getenv('ENV', 'development')}")
    yield
    logger.info("🛑 FlowPath AI Engine shutting down")

# ── FastAPI App ──────────────────────────────────────────────
app = FastAPI(
    title="FlowPath AI Engine",
    description="""
    GreenWave traffic optimization and signal prediction service.

    **Features:**
    - Real-time traffic signal phase prediction
    - GreenWave speed optimization for single signals and full routes
    - Congestion scoring and density analysis
    - Eco-driving metrics (fuel saved, CO₂ reduced)
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ── Middleware ───────────────────────────────────────────────
app.add_middleware(CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ── API Key Auth ─────────────────────────────────────────────
API_KEY_HEADER = APIKeyHeader(name="X-API-Key", auto_error=False)
EXPECTED_KEY   = os.getenv("AI_ENGINE_API_KEY", "dev-key")

async def verify_api_key(api_key: str = Security(API_KEY_HEADER)):
    if EXPECTED_KEY == "dev-key":
        return api_key  # Skip verification in development
    if not api_key or api_key != EXPECTED_KEY:
        raise HTTPException(status_code=403, detail="Invalid or missing API key")
    return api_key

# ── Routers ──────────────────────────────────────────────────
app.include_router(
    prediction.router,
    prefix="/predict",
    tags=["Signal Prediction"],
    dependencies=[Depends(verify_api_key)],
)
app.include_router(
    optimization.router,
    prefix="/optimize",
    tags=["GreenWave Optimization"],
    dependencies=[Depends(verify_api_key)],
)

# ── Health Endpoints ─────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "ok",
        "service": "FlowPath AI Engine",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
    }

@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "FlowPath AI Engine",
        "docs": "/docs",
        "health": "/health",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=os.getenv("ENV") == "development",
        workers=int(os.getenv("WORKERS", 2)),
        log_level="info",
    )
