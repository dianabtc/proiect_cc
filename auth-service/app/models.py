from sqlalchemy import Column, Integer, String
from .database import Base


class User(Base):
    """
    Database model for users.
    """

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    password = Column(String(255), nullable=False)
    role = Column(String(20), default="USER")
