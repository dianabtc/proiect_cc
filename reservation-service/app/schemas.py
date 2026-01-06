from datetime import date, time
from pydantic import BaseModel, Field, ConfigDict


# ---------- Halls ----------


class HallCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    location: str = Field(min_length=2, max_length=255)
    capacity: int = Field(gt=0)


class HallUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    location: str | None = Field(default=None, min_length=2, max_length=255)
    capacity: int | None = Field(default=None, gt=0)


class HallResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    location: str
    capacity: int


# ---------- Reservations ----------


class ReservationCreate(BaseModel):
    hall_id: int
    date: date
    start_time: time
    end_time: time


class ReservationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_sub: str
    hall_id: int
    date: date
    start_time: time
    end_time: time
    status: str


class AvailabilityQuery(BaseModel):
    hall_id: int
    date: date
    start_time: time
    end_time: time
