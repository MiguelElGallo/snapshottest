#!/usr/bin/env bash
# ------------------------------------------------------------------
# demo.sh -- inline-snapshot workflow: Create -> Break -> Fix
#
# Runs against REAL APIs (ip-api.com + Open-Meteo).
# Idempotent -- can be run repeatedly.
# ------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

# -- Colors --------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

# -- Files managed by the demo -------------------------------------
SOURCE_FILES=(
    src/snapshottest/models.py
    src/snapshottest/location.py
)
TEST_FILE="tests/test_demo.py"

# -- Helpers -------------------------------------------------------
pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${RESET}"
    read -r
    echo ""
}

banner() {
    echo ""
    echo -e "${BOLD}${CYAN}===========================================================${RESET}"
    echo -e "${BOLD}${CYAN}  $1${RESET}"
    echo -e "${BOLD}${CYAN}===========================================================${RESET}"
    echo ""
}

cleanup() {
    git checkout HEAD -- "${SOURCE_FILES[@]}" "$TEST_FILE" 2>/dev/null || true
}
trap cleanup EXIT

write_empty_test_file() {
    python3 << 'INNERPY'
import pathlib
pathlib.Path("tests/test_demo.py").write_text('''\
"""Demo tests -- empty snapshots, real APIs.

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
''')
INNERPY
}

append_summary_test() {
    python3 << 'INNERPY'
import pathlib
p = pathlib.Path("tests/test_demo.py")
p.write_text(p.read_text() + '''
def test_summary():
    """Snapshot the one-line human-readable summary."""
    report = build_weather_report()
    assert report.summary() == snapshot()
''')
INNERPY
}

# ==================================================================
# ACT 0 -- Reset & Explain
# ==================================================================

banner "Inline Snapshot Testing -- Interactive Demo"

echo "This demo walks through the full inline-snapshot workflow"
echo "using REAL APIs -- no mocks, no fake data."
echo ""
echo "  Act 1 -> Create snapshots from live API responses"
echo "  Act 2 -> Add a feature (continent) -> snapshots break"
echo "  Act 3 -> Fix snapshots automatically"
echo ""
echo -e "Test file: ${BOLD}${TEST_FILE}${RESET}"

pause

banner "Resetting to clean state..."
cleanup
write_empty_test_file
echo -e "${GREEN}Done: Source files restored, test file written with empty snapshots.${RESET}"

pause

# ==================================================================
# ACT 1 -- Create Snapshots (Real APIs)
# ==================================================================

banner "Act 1 -- Create Snapshots"

echo "The test file has 3 tests, each ending with an empty snapshot():"
echo ""
echo "    assert location.to_dict() == snapshot()   # <- empty!"
echo "    assert weather.to_dict()  == snapshot()   # <- empty!"
echo "    assert report.to_dict()   == snapshot()   # <- empty!"
echo ""
echo "These tests call REAL APIs -- no mocks. You did not type any expected values."
echo ""
echo -e "Running: ${BOLD}uv run pytest tests/test_demo.py -v${RESET}"
echo ""

uv run pytest tests/test_demo.py -v 2>&1 || true

echo ""
echo -e "${YELLOW}Warning: Empty snapshot() accepts any value -- tests pass, but with errors.${RESET}"

pause

echo -e "Now let's fill them in:"
echo -e "${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=create${RESET}"
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=create 2>&1 || true

echo ""
echo -e "${GREEN}Done: inline-snapshot rewrote the test file with your REAL data!${RESET}"
echo ""
echo -e "Open ${BOLD}tests/test_demo.py${RESET} -- the snapshots now contain your actual"
echo "location and current weather. You didn't type any of those values."

pause

echo -e "Verify -- run tests with no flags:"
echo ""

uv run pytest tests/test_demo.py -v 2>&1

echo ""
echo -e "${GREEN}All tests pass cleanly.${RESET}"

pause

# ==================================================================
# ACT 2 -- Break (Add Continent Feature)
# ==================================================================

banner "Act 2 -- Add a Feature (Continent)"

echo "Simulating a real feature addition:"
echo ""
echo "  1. Add 'continent' field to the Location model"
echo "  2. Request 'continent' from the ip-api.com API"
echo "  3. Add WMO_DESCRIPTIONS dict and summary() method"
echo "  4. Add a new test_summary() test"
echo ""
echo "Applying changes..."

cp demo/continent/models.py   src/snapshottest/models.py
cp demo/continent/location.py src/snapshottest/location.py
append_summary_test

echo -e "${GREEN}Done: Feature applied.${RESET}"
echo ""
echo -e "Let's see what broke:"
echo -e "${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=report${RESET}"
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=report 2>&1 || true

echo ""
echo -e "${RED}Existing snapshots broke -- Location.to_dict() now has a 'continent' key${RESET}"
echo -e "${YELLOW}  Plus test_summary has an empty snapshot() that needs filling.${RESET}"
echo ""
echo "inline-snapshot shows exactly what changed (read-only -- nothing modified)."

pause

# ==================================================================
# ACT 3 -- Fix (create + fix in one pass)
# ==================================================================

banner "Act 3 -- Fix Snapshots"

echo "One command handles BOTH broken and new snapshots:"
echo -e "${BOLD}uv run pytest tests/test_demo.py -v --inline-snapshot=create,fix${RESET}"
echo ""

uv run pytest tests/test_demo.py -v --inline-snapshot=create,fix 2>&1 || true

echo ""
echo -e "${GREEN}Done: Broken snapshots fixed + new snapshot created -- in one pass!${RESET}"

pause

echo -e "Final verification:"
echo ""

uv run pytest tests/test_demo.py -v 2>&1

echo ""
echo -e "${GREEN}All tests pass. The snapshots now include 'continent' and 'summary'.${RESET}"

pause

# ==================================================================
# DONE
# ==================================================================

banner "Done!"

echo "You've seen the full inline-snapshot workflow:"
echo ""
echo "  1. snapshot()                        -> empty, accepts anything"
echo "  2. --inline-snapshot=create          -> fills in real values from APIs"
echo "  3. Add feature -> snapshots break    -> report shows the diff"
echo "  4. --inline-snapshot=create,fix      -> updates old + fills new"
echo ""
echo "Key flags:"
echo "  --inline-snapshot=create   -> fill empty snapshots"
echo "  --inline-snapshot=fix      -> update broken snapshots"
echo "  --inline-snapshot=report   -> show diff, change nothing (CI)"
echo "  --inline-snapshot=review   -> interactive accept/reject"
echo ""
echo -e "Read ${BOLD}TUTORIAL.md${RESET} for the full written guide."
echo ""
echo -e "${CYAN}(Source files restored to their original state on exit.)${RESET}"
