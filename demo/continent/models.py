"""Data models for the weather report."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

# WMO weather code descriptions — plain text (no emoji) for programmatic use.
WMO_DESCRIPTIONS: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    71: "Slight snow",
    73: "Moderate snow",
    75: "Heavy snow",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}


@dataclass
class Location:
    """Geographic location derived from IP geolocation."""

    latitude: float
    longitude: float
    city: str
    country: str
    continent: str

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

    def summary(self) -> str:
        """One-line human-readable summary.

        Example: '18.5°C, Partly cloudy in Helsinki, Finland, Europe'
        """
        description = WMO_DESCRIPTIONS.get(
            self.weather.weather_code,
            f"Code {self.weather.weather_code}",
        )
        return (
            f"{self.weather.temperature_c}°C, {description} "
            f"in {self.location.city}, {self.location.country}, "
            f"{self.location.continent}"
        )
