"""Error-path test — uses a mock because you can't trigger API errors on demand.

The happy-path tests live in test_demo.py and call real APIs.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest
from inline_snapshot import snapshot

from snapshottest.location import get_location


class FakeHTTPResponse:
    """Minimal stand-in for httpx.Response."""

    def __init__(self, data: dict) -> None:
        self._data = data

    def raise_for_status(self) -> None:
        pass

    def json(self) -> dict:
        return self._data


def test_get_location_failure():
    """Verify RuntimeError when geolocation API fails."""
    error_response = {"status": "fail", "message": "reserved range"}
    with patch(
        "snapshottest.location.httpx.get",
        return_value=FakeHTTPResponse(error_response),
    ):
        with pytest.raises(RuntimeError) as exc_info:
            get_location()

    assert str(exc_info.value) == snapshot("Geolocation failed: reserved range")
