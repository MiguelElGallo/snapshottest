# Inline Snapshot Testing — A Hands-On Tutorial

You have a Python app that returns **structured data** — dictionaries, dataclasses, JSON blobs.

You want to write tests that check the **exact shape and values** of that data.

But you **don't** want to  hand-type giant expected dictionaries into every `assert`.

**`inline-snapshot`** does it for you. It writes the expected values *directly into your test source code* — and keeps them up to date when things change.

Let's see how.

---

## What You'll Build

A small weather CLI that:

1. Gets your **location** (latitude / longitude) from a free IP geolocation API.
2. Gets the **current temperature** for that location from a free weather API.
3. Displays the result in a pretty table.

Then you'll test it with `inline-snapshot` and see the full workflow:  **create → break → fix**.

---

## Project Setup

Create a new project with [UV](https://docs.astral.sh/uv/) and add the dependencies:

```console
$ uv init snapshottest --python 3.11
$ cd snapshottest
$ uv add httpx typer rich
$ uv add --group dev inline-snapshot pytest ruff
```

Your `pyproject.toml` should look like this:

```toml
[project]
name = "snapshottest"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.28.1",
    "rich>=14.3.3",
    "typer>=0.24.0",
]

[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.build_meta"

[dependency-groups]
dev = [
    "inline-snapshot>=0.32.2",
    "pytest>=9.0.2",
    "ruff>=0.15.2",
]

[tool.inline-snapshot]
format-command = "ruff format --stdin-filename {filename}"
```

!!! tip
    The `format-command` tells `inline-snapshot` to format the code it writes using **ruff**. This keeps the auto-generated snapshots consistent with your project style.

---

## The Source Code

The project uses a `src/` layout:

```
src/snapshottest/
├── __init__.py
├── models.py
├── location.py
└── weather.py
```

### Models

Three simple dataclasses that carry data through the app:

```python
# src/snapshottest/models.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass
class Location:
    latitude: float
    longitude: float
    city: str
    country: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Weather:
    temperature_c: float
    weather_code: int
    wind_speed_kmh: float

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class WeatherReport:
    location: Location
    weather: Weather

    def to_dict(self) -> dict[str, Any]:
        return {
            "location": self.location.to_dict(),
            "weather": self.weather.to_dict(),
        }
```

### Location

Uses [ip-api.com](http://ip-api.com) — free, no API key:

```python
# src/snapshottest/location.py
import httpx
from snapshottest.models import Location

IP_API_URL = "http://ip-api.com/json/"


def get_location() -> Location:
    response = httpx.get(
        IP_API_URL,
        params={"fields": "status,message,city,country,lat,lon"},
        timeout=10,
    )
    response.raise_for_status()
    data = response.json()

    if data.get("status") != "success":
        raise RuntimeError(
            f"Geolocation failed: {data.get('message', 'unknown error')}"
        )

    return Location(
        latitude=data["lat"],
        longitude=data["lon"],
        city=data["city"],
        country=data["country"],
    )
```

### Weather

Uses [Open-Meteo](https://open-meteo.com) — also free, no API key:

```python
# src/snapshottest/weather.py
import httpx
from snapshottest.models import Weather

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


def get_temperature(latitude: float, longitude: float) -> Weather:
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
```

---

## Step 1 — Write Tests with Empty Snapshots

Here's the key idea: you write your assertions with **empty `snapshot()` calls** and let the tool fill them in later.

Create `tests/test_demo.py`:

```python
from unittest.mock import patch
from inline_snapshot import snapshot
from snapshottest.location import get_location
from snapshottest.weather import get_temperature
from snapshottest.models import Location, Weather, WeatherReport
from snapshottest.cli import build_weather_report


# Fake API responses — deterministic data for tests
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
    def __init__(self, data: dict) -> None:
        self._data = data

    def raise_for_status(self) -> None:
        pass

    def json(self) -> dict:
        return self._data


def test_get_location():
    with patch(
        "snapshottest.location.httpx.get",
        return_value=FakeHTTPResponse(FAKE_IP_API_RESPONSE),
    ):
        location = get_location()

    assert location.to_dict() == snapshot()  # 👈 empty!


def test_get_temperature():
    with patch(
        "snapshottest.weather.httpx.get",
        return_value=FakeHTTPResponse(FAKE_OPEN_METEO_RESPONSE),
    ):
        weather = get_temperature(37.7749, -122.4194)

    assert weather.to_dict() == snapshot()  # 👈 empty!


def test_build_weather_report():
    fake_location = Location(
        latitude=37.7749, longitude=-122.4194,
        city="San Francisco", country="United States",
    )
    fake_weather = Weather(
        temperature_c=18.5, weather_code=2, wind_speed_kmh=12.3,
    )

    with (
        patch("snapshottest.cli.get_location", return_value=fake_location),
        patch("snapshottest.cli.get_temperature", return_value=fake_weather),
    ):
        report = build_weather_report()

    assert report.to_dict() == snapshot()  # 👈 empty!


def test_weather_report_structure():
    report = WeatherReport(
        location=Location(
            latitude=40.7128, longitude=-74.0060,
            city="New York", country="United States",
        ),
        weather=Weather(
            temperature_c=22.0, weather_code=0, wind_speed_kmh=8.5,
        ),
    )
    data = report.to_dict()

    assert data["location"]["city"] == snapshot()  # 👈 empty!
```

Notice every `assert` ends with an **empty `snapshot()`**. You don't write expected values — you let the tool do it.

Now run the tests:

```console
$ uv run pytest tests/test_demo.py -v
```

```
tests/test_demo.py::test_get_location PASSED
tests/test_demo.py::test_get_location ERROR
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_get_temperature ERROR
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_build_weather_report ERROR
tests/test_demo.py::test_weather_report_structure PASSED
tests/test_demo.py::test_weather_report_structure ERROR

4 passed, 4 errors in 0.08s
```

!!! warning
    **4 passed.** Wait — the snapshots are *empty*! How can they pass?

    An empty `snapshot()` with `==` passes silently. It accepts **any value**. The `ERROR` entries are warnings telling you that snapshot values are missing, but the tests themselves **don't fail**.

    This is intentional — it lets you write and run tests immediately, then fill in the snapshots when you're ready.

---

## Step 2 — Create the Snapshots

Now let `inline-snapshot` fill in the values by running with `--inline-snapshot=create`:

```console
$ uv run pytest tests/test_demo.py -v --inline-snapshot=create
```

```
tests/test_demo.py::test_get_location PASSED
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_weather_report_structure PASSED

──────────────────────── Create snapshots ────────────────────────
╭──────────────────── tests/test_demo.py ────────────────────╮
│ @@ -55,7 +55,14 @@                                        │
│                                                            │
│      assert location.to_dict() == snapshot(                │
│ -        )                                                 │
│ +        {                                                 │
│ +            "latitude": 37.7749,                          │
│ +            "longitude": -122.4194,                       │
│ +            "city": "San Francisco",                      │
│ +            "country": "United States",                   │
│ +        }                                                 │
│ +    )                                                     │
│                                                            │
│      assert weather.to_dict() == snapshot(                 │
│ -        )                                                 │
│ +        {"temperature_c": 18.5, ...}                      │
│                                                            │
│      assert report.to_dict() == snapshot(                  │
│ -        )                                                 │
│ +        {                                                 │
│ +            "location": {                                 │
│ +                "latitude": 37.7749,                      │
│ +                ...                                       │
│ +            },                                            │
│ +            "weather": { ... },                           │
│ +        }                                                 │
│                                                            │
│      assert data["location"]["city"] == snapshot(          │
│ -        )                                                 │
│ +        "New York"                                        │
│ +    )                                                     │
╰────────────────────────────────────────────────────────────╯

4 passed in 0.08s
```

**`inline-snapshot` rewrote your test file.** Open `tests/test_demo.py` — the empty `snapshot()` calls are now filled:

```python
# BEFORE (you wrote this)
assert location.to_dict() == snapshot()

# AFTER (inline-snapshot wrote this)
assert location.to_dict() == snapshot(
    {
        "latitude": 37.7749,
        "longitude": -122.4194,
        "city": "San Francisco",
        "country": "United States",
    }
)
```

Run the tests one more time to confirm everything is clean:

```console
$ uv run pytest tests/test_demo.py -v
```

```
tests/test_demo.py::test_get_location PASSED
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_weather_report_structure PASSED

4 passed in 0.04s
```

!!! tip
    The snapshots are **right there in your test file** — not in a separate `.snap` file or directory. You can read them, review them in PRs, and `git diff` them like any other code.

---

## Step 3 — Break the Snapshots

Now simulate a code change. Imagine the geolocation API starts returning a different city because the user moved. Update the fake data in `tests/test_demo.py`:

```python
# Change the fake response
FAKE_IP_API_RESPONSE = {
    "status": "success",
    "city": "Los Angeles",           # was "San Francisco"
    "country": "United States",
    "lat": 34.0522,                  # was 37.7749
    "lon": -118.2437,                # was -122.4194
}
```

Run the tests:

```console
$ uv run pytest tests/test_demo.py -v --inline-snapshot=report
```

```
tests/test_demo.py::test_get_location FAILED
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_weather_report_structure PASSED

──────────────────────── Fix snapshots ────────────────────────
╭──────────────────── tests/test_demo.py ────────────────────╮
│ @@ -60,9 +60,9 @@                                         │
│                                                            │
│      assert location.to_dict() == snapshot(                │
│          {                                                 │
│ -            "latitude": 37.7749,                          │
│ -            "longitude": -122.4194,                       │
│ -            "city": "San Francisco",                      │
│ +            "latitude": 34.0522,                          │
│ +            "longitude": -118.2437,                       │
│ +            "city": "Los Angeles",                        │
│              "country": "United States",                   │
│          }                                                 │
│      )                                                     │
╰────────────────────────────────────────────────────────────╯
These changes are not applied.
Use --inline-snapshot=fix to apply them.

FAILED tests/test_demo.py::test_get_location - AssertionError

1 failed, 3 passed, 1 error in 0.12s
```

`inline-snapshot` tells you **exactly** what changed and shows you the diff. The test fails because the snapshot still says `"San Francisco"` but the code now produces `"Los Angeles"`.

!!! info
    Using `--inline-snapshot=report` shows the diff without modifying anything. This is great for CI — you can see what *would* change without actually changing files.

---

## Step 4 — Fix the Snapshots

You've reviewed the diff and the new values look correct. Update the snapshots automatically:

```console
$ uv run pytest tests/test_demo.py -v --inline-snapshot=fix
```

```
tests/test_demo.py::test_get_location PASSED
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_weather_report_structure PASSED

──────────────────────── Fix snapshots ────────────────────────
╭──────────────────── tests/test_demo.py ────────────────────╮
│ @@ -60,9 +60,9 @@                                         │
│                                                            │
│      assert location.to_dict() == snapshot(                │
│          {                                                 │
│ -            "latitude": 37.7749,                          │
│ -            "longitude": -122.4194,                       │
│ -            "city": "San Francisco",                      │
│ +            "latitude": 34.0522,                          │
│ +            "longitude": -118.2437,                       │
│ +            "city": "Los Angeles",                        │
│              "country": "United States",                   │
│          }                                                 │
│      )                                                     │
╰────────────────────────────────────────────────────────────╯
These changes will be applied, because you used fix

4 passed, 1 error in 0.17s
```

Run once more to confirm:

```console
$ uv run pytest tests/test_demo.py -v
```

```
tests/test_demo.py::test_get_location PASSED
tests/test_demo.py::test_get_temperature PASSED
tests/test_demo.py::test_build_weather_report PASSED
tests/test_demo.py::test_weather_report_structure PASSED

4 passed in 0.04s
```

Clean. The snapshot in your test file now reads `"Los Angeles"` instead of `"San Francisco"`.

---

## The Full Workflow

Here's the `inline-snapshot` workflow at a glance:

| Step | Command | What happens |
|------|---------|-------------|
| **Write** | `assert x == snapshot()` | Empty snapshot — accepts any value |
| **Create** | `pytest --inline-snapshot=create` | Fills in empty snapshots with actual values |
| **Report** | `pytest --inline-snapshot=report` | Shows a diff of what would change (read-only) |
| **Fix** | `pytest --inline-snapshot=fix` | Overwrites stale snapshots with new values |
| **Review** | `pytest --inline-snapshot=review` | Interactive mode — accept/reject each change |

!!! tip
    In CI, use `--inline-snapshot=report` to detect snapshot drift without modifying files. If the report shows changes, fail the build and tell the developer to run `--inline-snapshot=fix` locally.

---

## Why Inline Snapshots?

- **No separate snapshot files.** The expected values live right in the `assert` statement, in the same file, on the same line. You read them in code review the same way you'd read any other assertion.

- **No hand-typing giant dicts.** Write `snapshot()`, run `create`, done. The tool even formats the output with your project's formatter (ruff, black, etc.).

- **Easy to update.** When your code changes, run `fix` and the snapshots update automatically. Review the `git diff` to make sure the changes make sense.

- **Standard `assert`.** It's just `assert x == snapshot(...)`. No custom test runners, no magic. Works with plain pytest.

---

## Running the Demo

A shell script is included to walk through all four steps interactively:

```console
$ chmod +x demo.sh
$ ./demo.sh
```

It will pause between each step so you can inspect the files and output.
