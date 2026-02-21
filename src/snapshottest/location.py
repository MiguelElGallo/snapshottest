"""Fetch geographic location from IP address using ip-api.com (free, no key)."""

from __future__ import annotations

import httpx

from snapshottest.models import Location

IP_API_URL = "http://ip-api.com/json/"


def get_location() -> Location:
    """Return the current location based on public IP geolocation.

    Uses http://ip-api.com/json/ — free tier, no API key required.
    Limited to 45 requests/minute.
    """
    response = httpx.get(
        IP_API_URL,
        params={"fields": "status,message,city,country,lat,lon"},
        timeout=10,
    )
    response.raise_for_status()
    data = response.json()

    if data.get("status") != "success":
        raise RuntimeError(f"Geolocation failed: {data.get('message', 'unknown error')}")

    return Location(
        latitude=data["lat"],
        longitude=data["lon"],
        city=data["city"],
        country=data["country"],
    )
