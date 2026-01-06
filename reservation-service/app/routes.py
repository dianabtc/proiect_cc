from datetime import time
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_

from .database import get_db
from .models import EventHall, Reservation
from .schemas import (
    HallCreate,
    HallUpdate,
    HallResponse,
    ReservationCreate,
    ReservationResponse,
)
from .deps import get_current_payload, require_role

router = APIRouter(tags=["Reservation Service"])


# --------------------
# Utility / validation
# --------------------


def _validate_time_interval(start: time, end: time) -> None:
    """Basic interval validation."""
    if start >= end:
        raise HTTPException(
            status_code=400, detail="start_time must be before end_time"
        )


def _has_conflict(db: Session, hall_id: int, date_, start: time, end: time) -> bool:
    """
    Checks if there is an ACTIVE reservation that overlaps the requested interval.
    Overlap condition: existing.start < new.end AND new.start < existing.end
    """
    conflict = (
        db.query(Reservation)
        .filter(
            Reservation.hall_id == hall_id,
            Reservation.date == date_,
            Reservation.status == "ACTIVE",
            and_(
                Reservation.start_time < end,
                start < Reservation.end_time,
            ),
        )
        .first()
    )

    return conflict is not None


# --------------------
# Health
# --------------------


@router.get("/health")
def health():
    return {"status": "ok"}


# --------------------
# Halls (ADMIN manages)
# --------------------


@router.post(
    "/halls",
    response_model=HallResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_role("ADMIN"))],
)
def create_hall(
    payload: dict = Depends(get_current_payload),
    db: Session = Depends(get_db),
    hall: HallCreate = None,
):
    """
    Create a new event hall (ADMIN only).
    """
    # (payload not used directly here, but kept for clarity)
    existing = db.query(EventHall).filter(EventHall.name == hall.name).first()
    if existing:
        raise HTTPException(
            status_code=400, detail="Hall with this name already exists"
        )

    entity = EventHall(name=hall.name, location=hall.location, capacity=hall.capacity)
    db.add(entity)
    db.commit()
    db.refresh(entity)
    return entity


@router.get("/halls", response_model=list[HallResponse])
def list_halls(db: Session = Depends(get_db)):
    """
    List all halls (public).
    """
    return db.query(EventHall).order_by(EventHall.id.asc()).all()


@router.get("/halls/{hall_id}", response_model=HallResponse)
def get_hall(hall_id: int, db: Session = Depends(get_db)):
    hall = db.query(EventHall).filter(EventHall.id == hall_id).first()
    if not hall:
        raise HTTPException(status_code=404, detail="Hall not found")
    return hall


@router.patch(
    "/halls/{hall_id}",
    response_model=HallResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
def update_hall(hall_id: int, patch: HallUpdate, db: Session = Depends(get_db)):
    hall = db.query(EventHall).filter(EventHall.id == hall_id).first()
    if not hall:
        raise HTTPException(status_code=404, detail="Hall not found")

    if patch.name is not None:
        hall.name = patch.name
    if patch.location is not None:
        hall.location = patch.location
    if patch.capacity is not None:
        hall.capacity = patch.capacity

    db.commit()
    db.refresh(hall)
    return hall


@router.delete(
    "/halls/{hall_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_role("ADMIN"))],
)
def delete_hall(hall_id: int, db: Session = Depends(get_db)):
    hall = db.query(EventHall).filter(EventHall.id == hall_id).first()
    if not hall:
        raise HTTPException(status_code=404, detail="Hall not found")

    db.delete(hall)
    db.commit()
    return None


# --------------------
# Reservations (USER makes bookings)
# --------------------


@router.get("/availability")
def check_availability(
    hall_id: int,
    date: str,
    start_time: str,
    end_time: str,
    db: Session = Depends(get_db),
):
    """
    Simple availability check (public).
    Query params example:
    /availability?hall_id=1&date=2026-01-06&start_time=10:00&end_time=12:00
    """
    from datetime import datetime

    try:
        d = datetime.strptime(date, "%Y-%m-%d").date()
        st = datetime.strptime(start_time, "%H:%M").time()
        et = datetime.strptime(end_time, "%H:%M").time()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date/time format")

    _validate_time_interval(st, et)

    hall = db.query(EventHall).filter(EventHall.id == hall_id).first()
    if not hall:
        raise HTTPException(status_code=404, detail="Hall not found")

    available = not _has_conflict(db, hall_id, d, st, et)
    return {"available": available}


@router.post(
    "/reservations",
    response_model=ReservationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_reservation(
    reservation: ReservationCreate,
    payload: dict = Depends(get_current_payload),
    db: Session = Depends(get_db),
):
    """
    Create a reservation (requires valid JWT).
    The user identity is taken from JWT payload 'sub'.
    """
    _validate_time_interval(reservation.start_time, reservation.end_time)

    hall = db.query(EventHall).filter(EventHall.id == reservation.hall_id).first()
    if not hall:
        raise HTTPException(status_code=404, detail="Hall not found")

    if _has_conflict(
        db,
        reservation.hall_id,
        reservation.date,
        reservation.start_time,
        reservation.end_time,
    ):
        raise HTTPException(status_code=409, detail="Time slot is already booked")

    user_sub = payload.get("sub")
    if not user_sub:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    entity = Reservation(
        user_sub=user_sub,
        hall_id=reservation.hall_id,
        date=reservation.date,
        start_time=reservation.start_time,
        end_time=reservation.end_time,
        status="ACTIVE",
    )
    db.add(entity)
    db.commit()
    db.refresh(entity)
    return entity


@router.get("/reservations", response_model=list[ReservationResponse])
def list_reservations(
    payload: dict = Depends(get_current_payload),
    db: Session = Depends(get_db),
):
    """
    USER sees own reservations; ADMIN sees all.
    """
    role = payload.get("role")
    user_sub = payload.get("sub")

    q = db.query(Reservation).order_by(Reservation.id.desc())
    if role != "ADMIN":
        q = q.filter(Reservation.user_sub == user_sub)

    return q.all()


@router.post(
    "/reservations/{reservation_id}/cancel", response_model=ReservationResponse
)
def cancel_reservation(
    reservation_id: int,
    payload: dict = Depends(get_current_payload),
    db: Session = Depends(get_db),
):
    """
    USER can cancel own reservation; ADMIN can cancel any.
    """
    role = payload.get("role")
    user_sub = payload.get("sub")

    res = db.query(Reservation).filter(Reservation.id == reservation_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Reservation not found")

    if role != "ADMIN" and res.user_sub != user_sub:
        raise HTTPException(status_code=403, detail="Forbidden")

    if res.status == "CANCELLED":
        return res

    res.status = "CANCELLED"
    db.commit()
    db.refresh(res)
    return res
