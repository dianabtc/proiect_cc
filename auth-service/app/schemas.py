from pydantic import BaseModel

# -------- Request schemas --------


class UserCreate(BaseModel):
    username: str
    password: str


class UserLogin(BaseModel):
    username: str
    password: str


# -------- Response schemas --------


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
