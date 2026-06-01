from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/api/health")
def health():
    return {"ok": True, "service": "wallet-portal", "version": "2.0.0"}
