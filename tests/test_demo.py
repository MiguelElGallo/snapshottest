"""Demo tests for the weather report app — starting with EMPTY snapshots."""

from __future__ import annotations

from unittest.mock import patch

from inline_snapshot import snapshot

from snapshottest.cli import build_weather_report
from snapshottest.location import get_location
from snapshottest.models import Location, Weather, WeatherReport
from snapshottest.weather import get_temperature

# ---------------------------------------------------------------------------
# Fake API responses used by all tests
# ---------------------------------------------------------------------------

FAKE_IP_API_RESPONSE = {
    "status": "success",
    "city": "Los Angeles",
    "country": "United States",
    "lat": 34.0522,
    "lon": -118.2437,
}

FAKE_OPEN_METEO_RESPONSE = {
    "current": {
        "temperature_2m": 18.5,
        "weather_code": 2,
        "wind_speed_10m": 12.3,
    }
}


class FakeHTTPResponse:
    """Minimal stand-in for httpx.Response."""

    def __init__(self, data: dict) -> None:
        self._data = data

    def raise_for_status(self) -> None:
        pass

    def json(self) -> dict:
        return self._data


# ---------------------------------------------------------------------------
# Tests — all snapshot() calls are EMPTY
# ---------------------------------------------------------------------------


def test_get_location():
    """Snapshot the Location object returned by get_location()."""
    with patch(
        "snapshottest.location.httpx.get",
        return_value=FakeHTTPResponse(FAKE_IP_API_RESPONSE),
    ):
        location = get_location()

    assert location.to_dict() == snapshot(
        {
            "latitude": 34.0522,
            "longitude": -118.2437,
            "city": "Los Angeles",
            "country": "United States",
        }
    )


def test_get_temperature():
    """Snapshot the Weather object returned by get_temperature()."""
    with patch(
        "snapshottest.weather.httpx.get",
        return_value=FakeHTTPResponse(FAKE_OPEN_METEO_RESPONSE),
    ):
        weather = get_temperature(37.7749, -122.4194)

    assert weather.to_dict() == snapshot(
        {"temperature_c": 18.5, "weather_code": 2, "wind_speed_kmh": 12.3}
    )


def test_build_weather_report():
    """Snapshot the full WeatherReport JSON."""
    fake_location = Location(
        latitude=37.7749,
        longitude=-122.4194,
        city="San Francisco",
        country="United States",
    )
    fake_weather = Weather(temperature_c=18.5, weather_code=2, wind_speed_kmh=12.3)

    with (
        patch("snapshottest.cli.get_location", return_value=fake_location),
        patch("snapshottest.cli.get_temperature", return_value=fake_weather),
    ):
        report = build_weather_report()

    assert report.to_dict() == snapshot(
        {
            "location": {
                "latitude": 37.7749,
                "longitude": -122.4194,
                "city": "San Francisco",
                "country": "United States",
            },
            "weather": {
                "temperature_c": 18.5,
                "weather_code": 2,
                "wind_speed_kmh": 12.3,
            },
        }
    )


def test_weather_report_structure():
    """Verify specific keys exist and values match snapshots."""
    report = WeatherReport(
        location=Location(
            latitude=40.7128,
            longitude=-74.0060,
            city="New York",
            country="United States",
        ),
        weather=Weather(temperature_c=22.0, weather_code=0, wind_speed_kmh=8.5),
    )
    data = report.to_dict()

    assert data["location"]["city"] == snapshot("New York")
    assert data["weather"]["temperature_c"] == snapshot(22.0)
    assert data["weather"]["weather_code"] == snapshot(0)
