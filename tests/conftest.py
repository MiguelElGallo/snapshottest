"""Shared test configuration."""

from __future__ import annotations

import httpx
import pytest


def pytest_collection_modifyitems(
    config: pytest.Config, items: list[pytest.Item]
) -> None:
    """Skip tests that hit real APIs when there is no internet connection."""
    # Only check once per session
    try:
        httpx.get("http://ip-api.com/json/?fields=status", timeout=5)
    except (httpx.HTTPError, httpx.ConnectError, OSError):
        skip = pytest.mark.skip(
            reason="No internet connection — skipping live API tests"
        )
        for item in items:
            # Skip test_demo tests (real APIs); keep test_weather_report (mocked)
            if "test_demo" in str(item.fspath):
                item.add_marker(skip)
