# Inline Snapshot Testing — Tutorial

Learn **inline-snapshot** by building tests against real APIs.
No mocks, no fake data — the tool discovers the expected values for you.

> **Style note** — this tutorial follows the same progressive approach as the
> [FastAPI Tutorial](https://fastapi.tiangolo.com/tutorial/).
> Each section builds on the previous one.

---

## What you will build

A small CLI app that reports the weather for your current location.
It uses two free APIs:

| API | Purpose | Auth |
|---|---|---|
| [ip-api.com](http://ip-api.com) | IP geolocation (city, country, coordinates) | None |
| [Open-Meteo](https://open-meteo.com) | Current weather (temperature, wind, conditions) | None |

The tests call these APIs for real.  `--inline-snapshot=create` fills in the
expected values automatically — so you never type fake data by hand.

---

## Prerequisites

- Python 3.11+
- [UV](https://docs.astral.sh/uv/) package manager
- Internet connection (the tests call live APIs)

---

## Quick start

```bash
git clone <this-repo> && cd snapshottest
uv sync
```

The project is already set up with all dependencies.

---

## The source code

### Models — `src/snapshottest/models.py`

Three dataclasses that represent the domain:

```python
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

Each model has a `to_dict()` method so we can snapshot plain dictionaries.

### Location — `src/snapshottest/location.py`

Calls [ip-api.com](http://ip-api.com/json/) to geolocate the machine's public IP:

```python
def get_location() -> Location:
    response = httpx.get(
        IP_API_URL,
        params={"fields": "status,message,city,country,lat,lon"},
        timeout=10,
    )
    response.raise_for_status()
    data = response.json()
    ...
    return Location(
        latitude=data["lat"],
        longitude=data["lon"],
        city=data["city"],
        country=data["country"],
    )
```

### Weather — `src/snapshottest/weather.py`

Calls [Open-Meteo](https://open-meteo.com) for the current temperature, weather code, and wind speed:

```python
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
    ...
    return Weather(
        temperature_c=current["temperature_2m"],
        weather_code=current["weather_code"],
        wind_speed_kmh=current["wind_speed_10m"],
    )
```

---

## Act 1 — Create snapshots

### Write the tests

Create `tests/test_demo.py` with three tests.  Each one calls a **real** function
and asserts against an **empty** `snapshot()`:

```python
from inline_snapshot import snapshot

from snapshottest.location import get_location
from snapshottest.weather import get_temperature
from snapshottest.cli import build_weather_report


def test_get_location():
    location = get_location()
    assert location.to_dict() == snapshot()


def test_get_temperature():
    weather = get_temperature(60.17, 24.94)   # Helsinki coords
    assert weather.to_dict() == snapshot()


def test_build_weather_report():
    report = build_weather_report()
    assert report.to_dict() == snapshot()
```

Notice: **you did not type any expected values**.  The `snapshot()` calls are
completely empty.

### Run the tests (no flags)

```bash
uv run pytest tests/test_demo.py -v
```

All three tests pass — but with warnings.  An empty `snapshot()` accepts any
value, so there is nothing to compare against yet.

### Fill in the snapshots

```bash
uv run pytest tests/test_demo.py -v --inline-snapshot=create
```

Open `tests/test_demo.py` again.  The empty `snapshot()` calls have been
**rewritten in-place** with the actual data returned by the APIs:

```python
def test_get_location():
    location = get_location()
    assert location.to_dict() == snapshot(
        {
            "latitude": 60.1797,
            "longitude": 24.9344,
            "city": "Helsinki",
            "country": "Finland",
        }
    )
```

> **Your values will differ** — they come from your IP and the current weather.
> That's the whole point: *you* didn't write them, `inline-snapshot` discovered
> them from the actual API responses.

### Verify

```bash
uv run pytest tests/test_demo.py -v
```

All tests pass cleanly — no warnings.

---

## Act 2 — Break the snapshots

Now you will add a feature: include the **continent** (e.g. "Europe") in the
location data.  This changes the structure returned by `to_dict()`, which means
the existing snapshots will no longer match.

### Update the models

Add a `continent` field to `Location`, a `WMO_DESCRIPTIONS` dict, and a
`summary()` method to `WeatherReport`:

```python
# models.py  (changes highlighted)

WMO_DESCRIPTIONS: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    ...
}


@dataclass
class Location:
    latitude: float
    longitude: float
    city: str
    country: str
    continent: str          # <-- NEW

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class WeatherReport:
    ...

    def summary(self) -> str:           # <-- NEW
        description = WMO_DESCRIPTIONS.get(
            self.weather.weather_code,
            f"Code {self.weather.weather_code}",
        )
        return (
            f"{self.weather.temperature_c}°C, {description} "
            f"in {self.location.city}, {self.location.country}, "
            f"{self.location.continent}"
        )
```

### Update `get_location()`

Request the `continent` field from ip-api.com and pass it to `Location`:

```python
# location.py  (changes highlighted)

response = httpx.get(
    IP_API_URL,
    params={"fields": "status,message,city,country,continent,lat,lon"},  # <-- continent added
    timeout=10,
)
...
return Location(
    latitude=data["lat"],
    longitude=data["lon"],
    city=data["city"],
    country=data["country"],
    continent=data["continent"],   # <-- NEW
)
```

### Add a test for `summary()`

Append to `tests/test_demo.py`:

```python
def test_summary():
    report = build_weather_report()
    assert report.summary() == snapshot()
```

### See what broke

```bash
uv run pytest tests/test_demo.py -v --inline-snapshot=report
```

`--inline-snapshot=report` is **read-only** — it shows you exactly what changed
but does **not** modify any files.  You will see:

- `test_get_location` and `test_build_weather_report` **fail**: their snapshots
  are missing the new `"continent"` key.
- `test_summary` has an empty `snapshot()` that needs filling.

---

## Act 3 — Fix the snapshots

One command handles **both** problems — broken snapshots **and** new empty ones:

```bash
uv run pytest tests/test_demo.py -v --inline-snapshot=create,fix
```

- `fix` updates the broken snapshots (adds `"continent": "Europe"`)
- `create` fills in the empty `test_summary` snapshot

### Verify

```bash
uv run pytest tests/test_demo.py -v
```

All four tests pass.  Open `tests/test_demo.py` to see the updated snapshots —
they now include the continent field and the summary string.

---

## The interactive demo script

The repository includes `demo.sh` which walks through all three acts
interactively.  It is idempotent — run it as many times as you like:

```bash
./demo.sh
```

The script:

1. **Resets** source files to the committed state (`git checkout HEAD`)
2. **Act 1** — writes empty test file, runs `--inline-snapshot=create`
3. **Act 2** — copies `demo/continent/` files over source, adds `test_summary`
4. **Act 3** — runs `--inline-snapshot=create,fix`
5. **Restores** source files on exit (via `trap`)

---

## Key `inline-snapshot` flags

| Flag | Effect |
|---|---|
| `--inline-snapshot=create` | Fill empty `snapshot()` calls with actual values |
| `--inline-snapshot=fix` | Update broken snapshots to match current output |
| `--inline-snapshot=create,fix` | Both at once |
| `--inline-snapshot=report` | Show diffs, change nothing (safe for CI) |
| `--inline-snapshot=review` | Interactive accept/reject per snapshot |

---

## Project structure

```
snapshottest/
├── src/snapshottest/
│   ├── models.py          # Location, Weather, WeatherReport
│   ├── location.py        # IP geolocation (ip-api.com)
│   ├── weather.py         # Current weather (Open-Meteo)
│   └── cli.py             # Typer CLI with Rich output
├── tests/
│   ├── conftest.py        # Network guard — skips tests when offline
│   ├── test_demo.py       # 3 tests, real APIs, inline snapshots
│   └── test_weather_report.py  # Error-path test (mocked)
├── demo/
│   └── continent/         # "After" source files for the feature step
│       ├── models.py
│       └── location.py
├── demo.sh                # Interactive 3-act demo script
├── TUTORIAL.md            # This file
└── pyproject.toml
```

---

## Why no mocks?

Traditional snapshot tests mock the API and hardcode the response — but then the
snapshot just echoes back the mock data you already typed.  The snapshot adds
zero value.

By calling **real APIs**, `--inline-snapshot=create` discovers values the
developer never typed.  When the data model changes (like adding `continent`),
the snapshots genuinely break, and `--inline-snapshot=fix` updates them from
fresh API responses.  That is the workflow inline-snapshot was designed for.
