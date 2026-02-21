"""Typer CLI for the weather report demo."""

from __future__ import annotations

import json

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from snapshottest.location import get_location
from snapshottest.models import WeatherReport
from snapshottest.weather import get_temperature

app = typer.Typer(help="Snapshot‑testing demo: display weather for your current location.")
console = Console()

# WMO weather code descriptions (subset)
WMO_CODES: dict[int, str] = {
    0: "Clear sky ☀️",
    1: "Mainly clear 🌤️",
    2: "Partly cloudy ⛅",
    3: "Overcast ☁️",
    45: "Fog 🌫️",
    48: "Depositing rime fog 🌫️",
    51: "Light drizzle 🌦️",
    53: "Moderate drizzle 🌦️",
    55: "Dense drizzle 🌧️",
    61: "Slight rain 🌧️",
    63: "Moderate rain 🌧️",
    65: "Heavy rain 🌧️",
    71: "Slight snow ❄️",
    73: "Moderate snow 🌨️",
    75: "Heavy snow 🌨️",
    80: "Slight rain showers 🌦️",
    81: "Moderate rain showers 🌧️",
    82: "Violent rain showers ⛈️",
    95: "Thunderstorm ⛈️",
    96: "Thunderstorm with slight hail ⛈️",
    99: "Thunderstorm with heavy hail ⛈️",
}


def build_weather_report() -> WeatherReport:
    """Orchestrate: get location → get temperature → build report."""
    location = get_location()
    weather = get_temperature(location.latitude, location.longitude)
    return WeatherReport(location=location, weather=weather)


def display_report(report: WeatherReport) -> None:
    """Pretty-print the weather report using Rich."""
    loc = report.location
    wthr = report.weather

    table = Table(show_header=False, box=None, padding=(0, 2))
    table.add_column(style="bold cyan")
    table.add_column()

    table.add_row("City", loc.city)
    table.add_row("Country", loc.country)
    table.add_row("Coordinates", f"{loc.latitude}, {loc.longitude}")
    table.add_row("Temperature", f"{wthr.temperature_c} °C")
    table.add_row("Wind Speed", f"{wthr.wind_speed_kmh} km/h")
    table.add_row("Condition", WMO_CODES.get(wthr.weather_code, f"Code {wthr.weather_code}"))

    console.print(Panel(table, title="🌍 Weather Report", border_style="blue"))


@app.command()
def weather(
    as_json: bool = typer.Option(False, "--json", "-j", help="Output raw JSON instead of a table."),
) -> None:
    """Show the current weather for your location."""
    report = build_weather_report()

    if as_json:
        console.print_json(json.dumps(report.to_dict()))
    else:
        display_report(report)


if __name__ == "__main__":
    app()
