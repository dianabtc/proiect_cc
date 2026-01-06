import jwt
from datetime import datetime, timedelta, timezone
import bcrypt

# JWT configuration
SECRET_KEY = "super-secret-key"  # will be moved to K8s Secret later
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60


def hash_password(password: str) -> str:
    """Hash plain password."""
    # Convert password to bytes and truncate to 72 bytes if needed
    password_bytes = password.encode("utf-8")[:72]

    # Generate salt and hash
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)

    # Return as string
    return hashed.decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Verify password against hash."""
    # Convert inputs to bytes
    plain_bytes = plain.encode("utf-8")[:72]
    hashed_bytes = hashed.encode("utf-8")

    # Verify
    return bcrypt.checkpw(plain_bytes, hashed_bytes)


def create_access_token(data: dict) -> str:
    """Generate JWT token."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})

    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    """Decode and validate JWT token."""
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
