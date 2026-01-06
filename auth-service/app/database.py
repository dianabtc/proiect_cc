from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# Database connection URL (from env variables)
DATABASE_URL = os.getenv(
    "DATABASE_URL", "mysql+pymysql://user:password@mysql:3306/auth_db"
)

# SQLAlchemy engine
engine = create_engine(DATABASE_URL)

# DB session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


# Dependency used in routes
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
