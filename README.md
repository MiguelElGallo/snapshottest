# snapshottest

Learn **inline-snapshot** by testing a real weather CLI — no mocks, no fake data.

The tests call live APIs. You write **empty** `snapshot()` calls, and `inline-snapshot` fills in the expected values for you.

---

## What is this?

A small Python CLI that fetches your location (via [ip-api.com](http://ip-api.com)) and current weather (via [Open-Meteo](https://open-meteo.com)), then displays a report.

The interesting part is the **tests**: they hit the real APIs, and `--inline-snapshot=create` writes the expected values into the test file automatically.

An interactive demo walks you through the full workflow in three acts:

1. **Create** — fill empty snapshots from live API responses
2. **Break** — add a feature (`continent`) that changes the data shape
3. **Fix** — update all snapshots in one command

> **Tip:** Read the full step-by-step walkthrough in [TUTORIAL.md](TUTORIAL.md).

---

## Requirements

* Python 3.11+
* [UV](https://docs.astral.sh/uv/) — a fast Python package manager
* Internet connection (the tests call live APIs)

---

## Install UV

If you don't have UV yet, install it with a single command:

```console
curl -LsSf https://astral.sh/uv/install.sh | sh
```

> **Note:** On macOS you can also use `brew install uv`. See the [UV docs](https://docs.astral.sh/uv/getting-started/installation/) for other options.

Verify it works:

```console
$ uv --version
uv 0.6.x
```

---

## Clone & install

```console
git clone https://github.com/miguelp/snapshottest.git
cd snapshottest
uv sync
```

That's it. `uv sync` creates the virtual environment and installs all dependencies.

---

## Run the demo

```console
./demo.sh
```

The script is **idempotent** — run it as many times as you want. It resets everything on each run and restores files on exit.

It will:

1. Write a test file with empty `snapshot()` calls
2. Run `--inline-snapshot=create` to fill them from live APIs
3. Apply the *continent* feature (breaks existing snapshots)
4. Run `--inline-snapshot=create,fix` to update everything in one pass

> **Info:** The demo requires an internet connection. It calls ip-api.com and Open-Meteo — both free, no API key needed.

---

## Run the CLI

```console
uv run python -m snapshottest.cli weather
```

Or as JSON:

```console
uv run python -m snapshottest.cli weather --json
```

---

## Run the tests

```console
uv run pytest tests/ -v
```

To fill empty snapshots:

```console
uv run pytest tests/ -v --inline-snapshot=create
```

> **Tip:** See all available flags in the [inline-snapshot docs](https://15r10nk.github.io/inline-snapshot/).

---

## Project structure

```text
snapshottest/
├── src/snapshottest/
│   ├── models.py            # Location, Weather, WeatherReport
│   ├── location.py          # IP geolocation (ip-api.com)
│   ├── weather.py           # Current weather (Open-Meteo)
│   └── cli.py               # Typer CLI + Rich output
├── tests/
│   ├── conftest.py          # Network guard (skip when offline)
│   ├── test_demo.py         # Real-API tests with inline snapshots
│   └── test_weather_report.py  # Error-path test
├── demo/
│   └── continent/           # Feature files used by demo.sh
├── demo.sh                  # Interactive 3-act demo
├── TUTORIAL.md              # Full written tutorial
└── pyproject.toml
```

---

## Learn more

* [TUTORIAL.md](TUTORIAL.md) — step-by-step guide through the whole workflow
* [inline-snapshot docs](https://15r10nk.github.io/inline-snapshot/) — the library this demo is built around
* [UV docs](https://docs.astral.sh/uv/) — the package manager used here
