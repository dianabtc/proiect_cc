import os
import httpx

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")


class AuthClientError(Exception):
    """Raised when auth service cannot validate token."""


async def validate_token(authorization_header: str) -> dict:
    """
    Calls Auth Service /auth/validate and returns the decoded token payload.
    Expects the full Authorization header: 'Bearer <token>'.
    """
    url = f"{AUTH_SERVICE_URL}/auth/validate"

    async with httpx.AsyncClient(timeout=5.0) as client:
        resp = await client.get(url, headers={"Authorization": authorization_header})

    if resp.status_code != 200:
        raise AuthClientError(resp.text)

    data = resp.json()
    # expected shape: {"valid": True, "payload": {...}}
    return data["payload"]
