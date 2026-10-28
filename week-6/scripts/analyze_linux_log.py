"""
Week 6, opdracht 6.5: analyse van Linux_2k.log (SSH-inlogpogingen).

Grafiek 1 (gewoon scripting, geen AI): aantal inlogpogingen per uur op een tijdschaal.
Grafiek 2 (AI/machine learning): welke bron-IP's/hosts de anomalie veroorzaken, met IsolationForest.

Gebruik: python3 analyze_linux_log.py
Verwacht Linux_2k.log één map hoger (week-6/). Schrijft twee PNG's naar ../images/.
"""

import re
from pathlib import Path

import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.ensemble import IsolationForest

SCRIPT_DIR = Path(__file__).resolve().parent
LOG_PATH = SCRIPT_DIR.parent / "Linux_2k.log"
IMAGES_DIR = SCRIPT_DIR.parent / "images"
IMAGES_DIR.mkdir(exist_ok=True)

# Voorbeeldregel:
# Jan 05 12:12:34 combo sshd(pam_unix)[23397]: authentication failure; logname= uid=0 euid=0 tty=NODEVssh ruser= rhost=218.188.2.4
LINE_RE = re.compile(
    r"^(?P<ts>\w{3}\s+\d{1,2}\s\d{2}:\d{2}:\d{2})\s+\S+\s+sshd\(pam_unix\)\[\d+\]:\s+"
    r"(?P<msg>authentication failure|check pass; user unknown)"
)
RHOST_RE = re.compile(r"rhost=(?P<rhost>\S+)")


def load_events() -> pd.DataFrame:
    rows = []
    with open(LOG_PATH, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = LINE_RE.search(line)
            if not m:
                continue
            rhost_m = RHOST_RE.search(line)
            rhost = rhost_m.group("rhost") if rhost_m else None
            if not rhost:
                continue
            # De dataset heeft geen jaartal; voor een tijdschaal per uur zetten we een vast jaar erbij.
            ts = pd.to_datetime("2000 " + m.group("ts"), format="%Y %b %d %H:%M:%S", errors="coerce")
            if pd.isna(ts):
                continue
            rows.append({"timestamp": ts, "rhost": rhost})
    return pd.DataFrame(rows)


def plot_attempts_per_hour(df: pd.DataFrame) -> None:
    """Grafiek 1: standaard scripting, geen AI."""
    hourly = df.set_index("timestamp").resample("1h").size()
    fig, ax = plt.subplots(figsize=(12, 4.5))
    hourly.plot(ax=ax, color="#1f6feb", linewidth=1.5)
    ax.set_title("SSH-inlogpogingen per uur (Linux_2k.log)")
    ax.set_xlabel("Tijd")
    ax.set_ylabel("Aantal pogingen")
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(IMAGES_DIR / "attempts_per_hour.png", dpi=130)
    plt.close(fig)
    print(f"Grafiek 1 opgeslagen: {IMAGES_DIR / 'attempts_per_hour.png'}")
    print(f"Piekuur: {hourly.idxmax()} met {hourly.max()} pogingen")


def plot_anomalous_sources(df: pd.DataFrame, top_n: int = 15) -> None:
    """Grafiek 2: IsolationForest wijst aan welke bronnen afwijkend zijn."""
    per_source = df.groupby("rhost")["timestamp"].agg(
        attempts="count",
        first_seen="min",
        last_seen="max",
    )
    # Burst-kenmerk: hoeveel pogingen deze bron in zijn drukste minuut deed.
    burst = (
        df.assign(minute=df["timestamp"].dt.floor("min"))
        .groupby(["rhost", "minute"])
        .size()
        .groupby("rhost")
        .max()
        .rename("max_per_minute")
    )
    features = per_source.join(burst).fillna({"max_per_minute": 0})

    model = IsolationForest(n_estimators=200, contamination=0.1, random_state=42)
    features["anomaly"] = model.fit_predict(features[["attempts", "max_per_minute"]])
    features["anomaly_label"] = features["anomaly"].map({-1: "Anomalie", 1: "Normaal"})

    top = features.sort_values("attempts", ascending=False).head(top_n)

    fig, ax = plt.subplots(figsize=(12, 6))
    colors = top["anomaly_label"].map({"Anomalie": "#d1242f", "Normaal": "#1f6feb"})
    ax.bar(range(len(top)), top["attempts"], color=colors)
    ax.set_xticks(range(len(top)))
    ax.set_xticklabels(top.index, rotation=60, ha="right", fontsize=8)
    ax.set_ylabel("Aantal inlogpogingen")
    ax.set_title("Inlogpogingen per bron, rood = anomalie volgens IsolationForest")
    handles = [
        plt.Rectangle((0, 0), 1, 1, color="#d1242f", label="Anomalie"),
        plt.Rectangle((0, 0), 1, 1, color="#1f6feb", label="Normaal"),
    ]
    ax.legend(handles=handles)
    fig.tight_layout()
    fig.savefig(IMAGES_DIR / "anomalous_sources.png", dpi=130)
    plt.close(fig)
    print(f"Grafiek 2 opgeslagen: {IMAGES_DIR / 'anomalous_sources.png'}")

    anomalies = features[features["anomaly_label"] == "Anomalie"].sort_values("attempts", ascending=False)
    print("\nDoor IsolationForest als anomalie aangemerkte bronnen:")
    print(anomalies[["attempts", "max_per_minute", "first_seen", "last_seen"]].to_string())


def main() -> None:
    df = load_events()
    print(f"{len(df)} sshd-authenticatieregels ingelezen uit {LOG_PATH}")
    plot_attempts_per_hour(df)
    plot_anomalous_sources(df)


if __name__ == "__main__":
    main()
