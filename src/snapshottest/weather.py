"""Fetch current weather data using Open-Meteo (free, no key)."""

from __future__ import annotations

import httpx

from snapshottest.models import Weather

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


def get_temperature(latitude: float, longitude: float) -> Weather:
    """Return current weather for the given coordinates.

    Uses https://open-meteo.com — free tier, no API key required.
    """
    response = httpx.get(
        OPEN_METEO_URL,
        params={
            "latitude": latitude,
            "longitude": longitude,
            "current": "temperature_2m,weather_code,wind_speed_10m",
        },
        timeout=10,
    )
    response.raise_for_status()
    data = response.json()

    current = data["current"]
    return Weather(
        temperature_c=current["temperature_2m"],
        weather_code=current["weather_code"],
        wind_speed_kmh=current["wind_speed_10m"],
    )
