from sqlalchemy import (
    Column,
    Integer,
    String,
    Date,
    Time,
    Enum,
    ForeignKey,
    Index,
)
from sqlalchemy.orm import relationship
from .database import Base


class EventHall(Base):
    """
    Represents an event venue / hall that can be booked.
    """

    __tablename__ = "event_halls"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False, unique=True)
    location = Column(String(255), nullable=False)
    capacity = Column(Integer, nullable=False)

    reservations = relationship(
        "Reservation", back_populates="hall", cascade="all, delete-orphan"
    )


class Reservation(Base):
    """
    A reservation made by a user for a specific hall and time interval.
    """

    __tablename__ = "reservations"

    id = Column(Integer, primary_key=True, index=True)

    # We store user identity from Auth Service (JWT "sub") as a string
    user_sub = Column(String(120), nullable=False, index=True)

    hall_id = Column(Integer, ForeignKey("event_halls.id"), nullable=False, index=True)

    date = Column(Date, nullable=False, index=True)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)

    status = Column(
        Enum("ACTIVE", "CANCELLED", name="reservation_status"),
        nullable=False,
        default="ACTIVE",
    )

    hall = relationship("EventHall", back_populates="reservations")


# Helpful composite index for conflict checks
Index("ix_reservations_hall_date", Reservation.hall_id, Reservation.date)
