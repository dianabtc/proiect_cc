from fastapi import FastAPI
from .database import Base, engine
from .routes import router

# Create tables at startup (simple approach for a course project)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Reservation Service")

app.include_router(router)
