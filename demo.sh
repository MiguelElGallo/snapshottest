#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# demo.sh — Walk through the inline-snapshot workflow step by step
# ──────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

# Colors
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

TEST_FILE="tests/test_demo.py"

pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${RESET}"
    read -r
    echo ""
}

banner() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $1${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# Write the test file with empty snapshot() calls
# ─────────────────────────────────────────────────────────────

write_empty_test_file() {
    cat > "$TEST_FILE" << 'EOF'
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
    "city": "San Francisco",
    "country": "United States",
    "lat": 37.7749,
    "lon": -122.4194,
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

    assert location.to_dict() == snapshot()


def test_get_temperature():
    """Snapshot the Weather object returned by get_temperature()."""
    with patch(
        "snapshottest.weather.httpx.get",
        return_value=FakeHTTPResponse(FAKE_OPEN_METEO_RESPONSE),
    ):
        weather = get_temperature(37.7749, -122.4194)

    assert weather.to_dict() == snapshot()


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

    assert report.to_dict() == snapshot()


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

    assert data["location"]["city"] == snapshot()
EOF
}

# ──────────────────────────────────────────────────────────────
# STEP 0 — Explain what we're doing
# ──────────────────────────────────────────────────────────────

banner "Inline Snapshot Testing — Interactive Demo"

echo "This demo walks through the full inline-snapshot workflow:"
echo ""
echo "  Step 1 → Write tests with empty snapshot() calls"
echo "  Step 2 → Create snapshots automatically"
echo "  Step 3 → Break the snapshots with a code change"
echo "  Step 4 → Fix the snapshots automatically"
echo ""
echo -e "Test file: ${BOLD}${TEST_FILE}${RESET}"

pause

# ──────────────────────────────────────────────────────────────
# STEP 1 — Empty snapshots pass (but warn)
# ──────────────────────────────────────────────────────────────

banner "Step 1 — Empty Snapshots"

echo -e "Writing test file with ${RED}empty snapshot()${RESET} calls..."
write_empty_test_file
echo ""
echo -e "${BOLD}Key assertion (no expected value):${RESET}"
echo ""
echo '    assert location.to_dict() == snapshot()  # ← empty!'
echo ""
echo -e "Running: ${BOLD}uv run pytest tests/test_demo.py -v${RESET}"
echo ""

uv run pytest tests/test_demo.py -v 2>&1 || true

echo ""
echo -e "${YELLOW}⚠  Notice: 4 passed, 4 errors.${RESET}"
echo "   The tests PASS because empty snapshot() accepts any value."
echo "   The ERRORs are warnings that snapshot values are missing."

pause

# ──────────────────────────────────────────────────────────────
# STEP 2 — Create snapshots
# ──────────────────────────────────────────────────────────────

banner "Step 2 — Create Snapshots"

echo -e "Running: ${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=create${RESET}"
echo ""
echo "This will fill in every empty snapshot() with the actual value."
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=create 2>&1 || true

echo ""
echo -e "${GREEN}✓ inline-snapshot rewrote the test file!${RESET}"
echo ""
echo -e "The snapshot now contains the actual values:"
echo ""
grep -A 8 'assert location.to_dict() == snapshot(' "$TEST_FILE" | head -10

pause

echo -e "Running tests again (no flags) to confirm they pass cleanly:"
echo ""

uv run pytest tests/test_demo.py -v 2>&1

pause

# ──────────────────────────────────────────────────────────────
# STEP 3 — Break the snapshots
# ──────────────────────────────────────────────────────────────

banner "Step 3 — Break the Snapshots"

echo "Simulating a code change: the user moved from San Francisco to Los Angeles."
echo ""
echo -e "Changing FAKE_IP_API_RESPONSE in the test file:"
echo '    "city": "San Francisco"  →  "city": "Los Angeles"'
echo '    "lat": 37.7749           →  "lat": 34.0522'
echo '    "lon": -122.4194         →  "lon": -118.2437'
echo ""

# Only change the FAKE_IP_API_RESPONSE at the top (lines 20-26),
# not the snapshot values deeper in the file.
sed -i '' '20,26{
    s/"city": "San Francisco"/"city": "Los Angeles"/
    s/"lat": 37.7749/"lat": 34.0522/
    s/"lon": -122.4194/"lon": -118.2437/
}' "$TEST_FILE"

echo -e "Running: ${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=report${RESET}"
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=report 2>&1 || true

echo ""
echo -e "${RED}✗ test_get_location FAILED${RESET}"
echo "  The snapshot still says 'San Francisco' but the code now returns 'Los Angeles'."
echo ""
echo -e "  inline-snapshot shows you ${BOLD}exactly${RESET} what needs to change."

pause

# ──────────────────────────────────────────────────────────────
# STEP 4 — Fix the snapshots
# ──────────────────────────────────────────────────────────────

banner "Step 4 — Fix the Snapshots"

echo -e "Running: ${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=fix${RESET}"
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=fix 2>&1 || true

echo ""
echo -e "${GREEN}✓ Snapshots updated!${RESET}"
echo ""
echo -e "The snapshot now reads:"
echo ""
grep -A 8 'assert location.to_dict() == snapshot(' "$TEST_FILE" | head -10

pause

echo -e "Final verification — all tests pass cleanly:"
echo ""

uv run pytest tests/test_demo.py -v 2>&1

echo ""

# ──────────────────────────────────────────────────────────────
# DONE
# ──────────────────────────────────────────────────────────────

banner "Done!"

echo "You've seen the full inline-snapshot workflow:"
echo ""
echo "  1. snapshot()                        → empty, accepts anything"
echo "  2. --inline-snapshot=create          → fills in the values"
echo "  3. Code changes break the snapshot   → test fails with a diff"
echo "  4. --inline-snapshot=fix             → updates the values"
echo ""
echo "Useful flags:"
echo "  --inline-snapshot=report  → show diff without changing files (CI)"
echo "  --inline-snapshot=review  → interactive accept/reject mode"
echo ""
echo -e "Read ${BOLD}TUTORIAL.md${RESET} for the full written guide."
