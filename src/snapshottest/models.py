"""Data models for the weather report."""

from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass
class Location:
    """Geographic location derived from IP geolocation."""

    latitude: float
    longitude: float
    city: str
    country: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Weather:
    """Current weather data for a location."""

    temperature_c: float
    weather_code: int
    wind_speed_kmh: float

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class WeatherReport:
    """Combined location + weather report."""

    location: Location
    weather: Weather

    def to_dict(self) -> dict[str, Any]:
        return {
            "location": self.location.to_dict(),
            "weather": self.weather.to_dict(),
        }
