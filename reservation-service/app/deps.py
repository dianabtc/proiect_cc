from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .auth_client import validate_token, AuthClientError

security = HTTPBearer()


async def get_current_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Extracts Bearer token from request and validates it via Auth Service.
    Returns JWT payload (e.g. sub, role, exp).
    """
    auth_header = f"Bearer {credentials.credentials}"
    try:
        payload = await validate_token(auth_header)
        return payload
    except AuthClientError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def require_role(required_role: str):
    """
    Dependency factory for role-based access.
    Usage: Depends(require_role("ADMIN"))
    """

    async def _checker(payload: dict = Depends(get_current_payload)) -> dict:
        role = payload.get("role")
        if role != required_role:
            raise HTTPException(status_code=403, detail="Forbidden")
        return payload

    return _checker
