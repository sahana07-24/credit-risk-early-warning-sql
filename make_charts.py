"""Draw the README charts from the CSVs in outputs/. Run after the SQL (run_analysis.py calls this)."""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).parent
OUT = ROOT / "outputs"
CHARTS = ROOT / "charts"

SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e6e5e0"
BLUE = "#2a78d6"     # good loans / primary series
ORANGE = "#eb6834"   # bad loans

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "font.family": "DejaVu Sans", "font.size": 11, "text.color": INK,
    "axes.labelcolor": INK_2, "xtick.color": INK_2, "ytick.color": INK_2,
    "axes.edgecolor": GRID, "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "axes.titlesize": 14, "axes.titleweight": "bold", "axes.titlelocation": "left",
})


def title(ax, main: str, sub: str) -> None:
    ax.set_title(main, pad=26)
    ax.text(0, 1.02, sub, transform=ax.transAxes, color=INK_2, fontsize=10.5, va="bottom")


def save(fig, name: str) -> None:
    fig.tight_layout()
    fig.savefig(CHARTS / name, dpi=160)
    plt.close(fig)


def chart_scorecard() -> None:
    df = pd.read_csv(OUT / "06_risk_scorecard.csv")
    fig, ax = plt.subplots(figsize=(9, 5))
    x = df["risk_score"]
    ax.bar(x, df["bad_rate_pct"], width=0.6, color=ORANGE, zorder=2)
    ax.errorbar(x, df["bad_rate_pct"],
                yerr=[df["bad_rate_pct"] - df["ci_low_pct"], df["ci_high_pct"] - df["bad_rate_pct"]],
                fmt="none", ecolor=INK_2, elinewidth=1.4, capsize=5, zorder=3)
    for xi, rate, hi in zip(x, df["bad_rate_pct"], df["ci_high_pct"]):
        ax.text(xi, hi + 2.5, f"{rate:.0f}%", ha="center", fontsize=11, fontweight="bold", color=INK)
    base = 100 * 76 / 682
    ax.axhline(base, color=INK_2, linestyle="--", linewidth=1)
    ax.text(4.45, base + 1.5, f"Portfolio average {base:.1f}%", color=INK_2, fontsize=9.5, ha="right")
    ax.set_xticks(x, [f"Score {s}\n{n} loans" for s, n in zip(x, df["loans"])])
    ax.set_ylim(0, 112)
    ax.set_ylabel("Loans that went bad (%)")
    ax.grid(axis="x", visible=False)
    title(ax, "More warning signs before the loan, far more bad loans",
          "Bad-loan rate by number of warning signs in the 6 months before lending (whiskers: 95% CI)")
    save(fig, "01_risk_scorecard.png")


def chart_signals() -> None:
    df = pd.read_csv(OUT / "05_pre_loan_behaviour.csv").set_index("signal")
    rows = [("pct_balance_fell_below_5k", "Balance fell below 5,000 CZK"),
            ("pct_paid_penalty_interest", "Paid penalty interest"),
            ("pct_went_overdrawn", "Went overdrawn")]
    fig, ax = plt.subplots(figsize=(10, 4.4))
    h = 0.36
    for i, (key, label) in enumerate(rows):
        y = len(rows) - 1 - i
        good, bad = df.loc[key, "Good loans"], df.loc[key, "Bad loans"]
        ax.barh(y + h / 2 + 0.02, bad, height=h, color=ORANGE, zorder=2)
        ax.barh(y - h / 2 - 0.02, good, height=h, color=BLUE, zorder=2)
        ax.text(bad + 1, y + h / 2 + 0.02, f"{bad:.0f}%", va="center", fontsize=10.5, color=INK)
        ax.text(good + 1, y - h / 2 - 0.02, f"{good:.1f}%", va="center", fontsize=10.5, color=INK)
    ax.set_yticks(range(len(rows)), [r[1] for r in reversed(rows)])
    ax.set_xlim(0, 75)
    ax.set_xlabel("Share of loans where this happened in the 6 months before lending (%)")
    ax.grid(axis="y", visible=False)
    ax.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=ORANGE), plt.Rectangle((0, 0), 1, 1, color=BLUE)],
              labels=["Bad loans (76)", "Good loans (606)"], loc="lower right", frameon=False)
    title(ax, "Bad borrowers were struggling before they borrowed",
          "Account warning signs before the loan date, bad vs good loans")
    save(fig, "02_warning_signs.png")


def chart_segments() -> None:
    df = pd.read_csv(OUT / "04_default_by_segment.csv")
    dims = ["Loan amount", "Monthly payment", "Loan duration"]
    sub = df[df["dimension"].isin(dims)].copy()
    sub["dimension"] = pd.Categorical(sub["dimension"], dims, ordered=True)
    sub = sub.sort_values("dimension", kind="stable").reset_index(drop=True)
    fig, ax = plt.subplots(figsize=(9, 6))
    ys, labels, y = [], [], 0
    prev = None
    for _, r in sub.iterrows():
        if prev is not None and r["dimension"] != prev:
            y += 0.8
        ys.append(y)
        labels.append(f"{r['segment']}  ({r['loans']})")
        prev = r["dimension"]
        y += 1
    ys = [max(ys) - v for v in ys]
    ax.errorbar(sub["bad_rate_pct"], ys,
                xerr=[sub["bad_rate_pct"] - sub["ci_low_pct"], sub["ci_high_pct"] - sub["bad_rate_pct"]],
                fmt="o", color=ORANGE, ecolor=INK_2, elinewidth=1.4, capsize=4, markersize=8, zorder=3)
    base = 100 * 76 / 682
    ax.axvline(base, color=INK_2, linestyle="--", linewidth=1)
    ax.text(base + 0.4, max(ys) + 0.7, f"Average {base:.1f}%", color=INK_2, fontsize=9.5)
    ax.set_yticks(ys, labels)
    starts = sub.groupby("dimension", observed=True).head(1).index
    for i in starts:
        ax.text(-0.01, ys[i] + 0.55, sub.loc[i, "dimension"], transform=ax.get_yaxis_transform(),
                ha="right", fontsize=10.5, fontweight="bold", color=INK)
    ax.set_xlabel("Bad-loan rate (%), with 95% confidence interval; loan count in brackets")
    ax.set_ylim(min(ys) - 0.7, max(ys) + 1.3)
    ax.grid(axis="y", visible=False)
    title(ax, "Bigger loans and payments go bad more often; term barely matters",
          "Bad-loan rate by loan size, payment and term")
    save(fig, "03_risk_by_loan_terms.png")


def chart_growth() -> None:
    df = pd.read_csv(OUT / "07_monthly_activity.csv", parse_dates=["month"])
    fig, ax = plt.subplots(figsize=(9, 4.4))
    ax.plot(df["month"], df["active_accounts"], color=BLUE, linewidth=2)
    last = df.iloc[-1]
    ax.annotate(f"{int(last['active_accounts']):,} active accounts\nDec 1998", (last["month"], last["active_accounts"]),
                xytext=(-10, -40), textcoords="offset points", ha="right", fontsize=10, color=INK)
    ax.set_ylabel("Accounts with a transaction that month")
    ax.set_ylim(0)
    ax.grid(axis="x", visible=False)
    title(ax, "The bank grew from 96 to over 4,400 active accounts in six years",
          "Monthly active accounts, Jan 1993 – Dec 1998")
    save(fig, "04_account_growth.png")


def main() -> None:
    CHARTS.mkdir(exist_ok=True)
    chart_scorecard()
    chart_signals()
    chart_segments()
    chart_growth()
    print(f"\nCharts saved to {CHARTS}")


if __name__ == "__main__":
    main()
