"""Demo tests — empty snapshots, real APIs.

Run with --inline-snapshot=create to fill in the values:
    uv run pytest tests/test_demo.py -v --inline-snapshot=create
"""

from __future__ import annotations

from inline_snapshot import snapshot

from snapshottest.location import get_location
from snapshottest.weather import get_temperature
from snapshottest.cli import build_weather_report


def test_get_location():
    """Snapshot the location returned by IP geolocation."""
    location = get_location()
    assert location.to_dict() == snapshot()


def test_get_temperature():
    """Snapshot the weather for Helsinki coordinates."""
    weather = get_temperature(60.17, 24.94)
    assert weather.to_dict() == snapshot()


def test_build_weather_report():
    """Snapshot the full weather report (location + weather)."""
    report = build_weather_report()
    assert report.to_dict() == snapshot()
