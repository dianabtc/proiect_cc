from fastapi import FastAPI
from fastapi.security import HTTPBearer
from .database import Base, engine
from .routes import router as auth_router

# Create DB tables at startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Auth Service", root_path="/auth")

# Register routes
app.include_router(auth_router)

# Add security scheme
security = HTTPBearer()


@app.get("/health")
def health_check():
    """Health check endpoint for Kubernetes."""
    return {"status": "ok"}
