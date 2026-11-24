"""Render the charts of docs/insights.md from the mart layer.

Each chart reads one query of analyses/, compiled by dbt, so the numbers in the
charts are the answers to the case-study questions as written in SQL.

From the host, after a build:

    make insights

That target runs `dbt compile --select path:analyses`, then this script inside
the dbt container. Connection settings come from PGHOST, PGPORT, PGDATABASE,
PGUSER and PGPASSWORD, with the docker-compose values as defaults.
"""

import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
import psycopg2  # noqa: E402
from matplotlib.ticker import FuncFormatter, PercentFormatter  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
COMPILED_ANALYSES = ROOT / "target" / "compiled" / "product_funnel_analysis" / "analyses"
OUTPUT_DIR = ROOT / "docs" / "img"

# Light-mode chart tokens: categorical slots validated for colour-vision deficiency.
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
INK_MUTED = "#898781"
GRID = "#e1e0d9"
BASELINE = "#c3c2b7"
SERIES_1 = "#2a78d6"
SERIES_2 = "#eb6834"

BAR_HEIGHT = 0.55

# Canonical values are kept in the marts; readable labels exist only here.
CATEGORY_LABELS = {
    "HOME_&_GARDEN": "Home & Garden",
    "UNDEFINED": "Undefined",
}
REASON_LABELS = {
    "card_declined": "Card declined",
    "customer_abandoned": "Customer abandoned",
    "inventory_shortage": "Inventory shortage",
    "lost_in_shipping": "Lost in shipping",
}


def category_label(category: str) -> str:
    return CATEGORY_LABELS.get(category, category.capitalize())


def reason_label(reason: str) -> str:
    return REASON_LABELS.get(reason, reason.replace("_", " ").capitalize())


def compact(value: float) -> str:
    return f"{value / 1000:.1f}K" if abs(value) >= 1000 else f"{value:,.0f}"


def compact_tick(value: float, _position=None) -> str:
    return f"{value / 1000:.0f}K" if value else "0"


def read_analysis(connection, name: str) -> pd.DataFrame:
    path = COMPILED_ANALYSES / f"{name}.sql"
    if not path.exists():
        raise SystemExit(f"{path} not found: run `dbt compile --select path:analyses` first.")
    with connection.cursor() as cursor:
        cursor.execute(path.read_text())
        columns = [column.name for column in cursor.description]
        frame = pd.DataFrame(cursor.fetchall(), columns=columns)
    # Postgres numerics arrive as Decimal: convert them for plotting.
    for column in frame.columns:
        if frame[column].map(lambda value: type(value).__name__ == "Decimal").any():
            frame[column] = frame[column].astype(float)
    return frame


def style_axis(axis, grid_axis: str = "x") -> None:
    axis.set_facecolor(SURFACE)
    for side in ("top", "right"):
        axis.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        axis.spines[side].set_color(BASELINE)
        axis.spines[side].set_linewidth(1)
    axis.tick_params(colors=INK_MUTED, labelcolor=INK_SECONDARY, length=0, labelsize=9)
    axis.grid(axis=grid_axis, color=GRID, linewidth=1)
    axis.set_axisbelow(True)


def new_figure(columns: int = 1, width: float = 8.0, height: float = 4.2):
    figure, axes = plt.subplots(1, columns, figsize=(width, height), sharey=columns > 1)
    figure.patch.set_facecolor(SURFACE)
    return figure, axes


def finish(figure, title: str, subtitle: str, filename: str) -> None:
    # Header positions in inches, so short and tall figures get the same spacing.
    height = figure.get_figheight()
    figure.text(0.02, 1 - 0.15 / height, title, ha="left", va="top", fontsize=13, fontweight="bold", color=INK)
    figure.text(0.02, 1 - 0.45 / height, subtitle, ha="left", va="top", fontsize=9.5, color=INK_SECONDARY)
    figure.tight_layout(rect=(0, 0, 1, 1 - 0.75 / height))
    figure.savefig(OUTPUT_DIR / filename, dpi=200, facecolor=SURFACE)
    plt.close(figure)
    print(f"wrote docs/img/{filename}")


def label_bars(axis, values, texts, offset: float) -> None:
    for position, (value, text) in enumerate(zip(values, texts)):
        axis.text(value + offset, position, text, va="center", fontsize=9, color=INK_SECONDARY)


def chart_funnel(funnel: pd.DataFrame) -> None:
    figure, axis = new_figure(height=3.2)
    funnel = funnel.sort_values("step_order", ascending=False).reset_index(drop=True)
    labels = funnel["step"].str.capitalize()
    axis.barh(labels, funnel["orders"], height=BAR_HEIGHT, color=SERIES_1)
    texts = [
        f"{orders:,.0f} orders"
        + ("" if step == "created" else f" · {cumulative:.1%} of created · step {step_rate:.1%}")
        for orders, cumulative, step_rate, step in zip(
            funnel["orders"],
            funnel["cumulative_conversion_rate"],
            funnel["step_conversion_rate"],
            funnel["step"],
        )
    ]
    label_bars(axis, funnel["orders"], texts, offset=12)
    axis.set_xlim(0, funnel["orders"].max() * 1.6)
    axis.xaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:,.0f}"))
    style_axis(axis)
    fulfilled = funnel.loc[funnel["step"] == "fulfilled", "cumulative_conversion_rate"].iloc[0]
    finish(
        figure,
        f"{fulfilled:.1%} of created orders are fulfilled",
        "Order funnel over the observation window (6 Mar – 4 Sep 2025)",
        "funnel.png",
    )


def chart_conversion_by_cohort(cohorts: pd.DataFrame) -> None:
    figure, axis = new_figure(height=3.8)
    months = pd.to_datetime(cohorts["cohort_month"])
    rates = cohorts["created_to_fulfilled"]
    axis.plot(months, rates, color=SERIES_1, linewidth=2, solid_capstyle="round", zorder=2)
    for month, rate, partial, orders in zip(
        months, rates, cohorts["is_partial_month"], cohorts["created_orders"]
    ):
        axis.scatter(
            month,
            rate,
            s=60,
            zorder=3,
            facecolor=SURFACE if partial else SERIES_1,
            edgecolor=SERIES_1,
            linewidth=2,
        )
        if partial:
            axis.annotate(
                f"{month:%b}: {rate:.0%}\n(partial, {orders} orders)",
                (month, rate),
                textcoords="offset points",
                # First month labelled to the right, last to the left: clear of the axes.
                xytext=(-6, -32) if month == months.max() else (6, -32),
                ha="right" if month == months.max() else "left",
                fontsize=8.5,
                color=INK_SECONDARY,
            )
    axis.set_ylim(0, 1)
    axis.yaxis.set_major_formatter(PercentFormatter(1.0, decimals=0))
    axis.set_xticks(months)
    axis.set_xticklabels([f"{month:%b}" for month in months])
    style_axis(axis, grid_axis="y")
    finish(
        figure,
        "Full months convert steadily at 86–90%",
        "Created → fulfilled by month of order creation · hollow markers are partial months",
        "conversion_by_cohort.png",
    )


def chart_categories(categories: pd.DataFrame) -> None:
    figure, (left, right) = new_figure(columns=2, height=4.0)
    categories = categories.sort_values("orders").reset_index(drop=True)
    labels = categories["category"].map(category_label)
    left.barh(labels, categories["orders"], height=BAR_HEIGHT, color=SERIES_1)
    label_bars(left, categories["orders"], [f"{value:,.0f}" for value in categories["orders"]], 4)
    left.set_xlim(0, categories["orders"].max() * 1.2)
    left.set_title("Created orders", loc="left", fontsize=10, color=INK)
    right.barh(labels, categories["gmv"], height=BAR_HEIGHT, color=SERIES_1)
    label_bars(right, categories["gmv"], [compact(value) for value in categories["gmv"]], 600)
    right.set_xlim(0, categories["gmv"].max() * 1.25)
    right.xaxis.set_major_formatter(FuncFormatter(compact_tick))
    right.set_title("GMV of fulfilled orders", loc="left", fontsize=10, color=INK)
    for axis in (left, right):
        style_axis(axis)
    finish(
        figure,
        "Home & Garden leads on volume, Electronics on value",
        "By product category, sorted by created orders",
        "categories.png",
    )


def chart_tiers(tiers: pd.DataFrame) -> None:
    figure, axes = new_figure(columns=3, width=9.0, height=3.0)
    tiers = tiers.iloc[::-1].reset_index(drop=True)
    labels = tiers["subs_tier"].str.capitalize()
    panels = [
        ("overall_conversion_rate", "Created → fulfilled", lambda value: f"{value:.1%}", 1.0),
        ("orders_per_30_days", "Orders per 30 days", lambda value: f"{value:.2f}", None),
        ("gmv_per_30_days", "GMV per 30 days", lambda value: f"{value:.0f}", None),
    ]
    for axis, (column, title, formatter, limit) in zip(axes, panels):
        values = tiers[column]
        axis.barh(labels, values, height=BAR_HEIGHT, color=SERIES_1)
        top = limit or values.max() * 1.35
        label_bars(axis, values, [formatter(value) for value in values], top * 0.02)
        axis.set_xlim(0, top * (1.3 if limit else 1))
        axis.set_title(title, loc="left", fontsize=10, color=INK)
        axis.set_xticks([])
        style_axis(axis)
        axis.grid(False)
    finish(
        figure,
        "Tiers barely change how customers order",
        "Tier at order time · per-30-day metrics on subscription periods with ≥ 30 days of exposure",
        "tiers.png",
    )


def chart_dropoffs(dropoffs: pd.DataFrame) -> None:
    figure, axis = new_figure(height=3.4)
    dropoffs = dropoffs.sort_values(["dropped_orders", "lost_gmv"], kind="stable").reset_index(drop=True)
    labels = dropoffs["dropoff_reason"].map(reason_label)
    colors = dropoffs["dropoff_stage"].map({"created": SERIES_1, "payment": SERIES_2})
    axis.barh(labels, dropoffs["dropped_orders"], height=BAR_HEIGHT, color=colors)
    texts = [
        f"{orders:,.0f} orders ({share:.0%}) · {compact(gmv)} GMV lost"
        for orders, share, gmv in zip(
            dropoffs["dropped_orders"], dropoffs["share_of_dropoffs"], dropoffs["lost_gmv"]
        )
    ]
    label_bars(axis, dropoffs["dropped_orders"], texts, 0.6)
    axis.set_xlim(0, dropoffs["dropped_orders"].max() * 2.0)
    style_axis(axis)
    handles = [
        plt.Rectangle((0, 0), 1, 1, color=SERIES_1, label="Before payment"),
        plt.Rectangle((0, 0), 1, 1, color=SERIES_2, label="After payment"),
    ]
    axis.legend(handles=handles, loc="lower right", frameon=False, fontsize=9, labelcolor=INK_SECONDARY)
    finish(
        figure,
        "Two thirds of dropoffs happen before payment",
        "Dropped orders by reason, coloured by the last stage reached",
        "dropoffs.png",
    )


def chart_carriers(carriers: pd.DataFrame) -> None:
    figure, (left, right) = new_figure(columns=2, width=9.0, height=4.0)
    carriers = carriers.sort_values("lost_in_shipping_rate").reset_index(drop=True)
    labels = carriers["shipping_company_name"]
    left.barh(labels, carriers["lost_in_shipping_rate"], height=BAR_HEIGHT, color=SERIES_1)
    label_bars(
        left,
        carriers["lost_in_shipping_rate"],
        [
            f"{rate:.1%} ({lost} of {paid})"
            for rate, lost, paid in zip(
                carriers["lost_in_shipping_rate"],
                carriers["lost_in_shipping_orders"],
                carriers["paid_orders"],
            )
        ],
        0.002,
    )
    left.set_xlim(0, carriers["lost_in_shipping_rate"].max() * 1.6)
    left.xaxis.set_major_formatter(PercentFormatter(1.0, decimals=0))
    left.set_title("Paid orders lost in shipping", loc="left", fontsize=10, color=INK)
    right.barh(labels, carriers["median_hours_to_fulfillment"], height=BAR_HEIGHT, color=SERIES_1)
    label_bars(
        right,
        carriers["median_hours_to_fulfillment"],
        [f"{hours:.0f} h" for hours in carriers["median_hours_to_fulfillment"]],
        2,
    )
    right.set_xlim(0, carriers["median_hours_to_fulfillment"].max() * 1.2)
    right.set_title("Median hours from payment to fulfilment", loc="left", fontsize=10, color=INK)
    for axis in (left, right):
        style_axis(axis)
    finish(
        figure,
        "USPS Priority and LaserShip lose 4–5× more parcels than the best carriers",
        "By shipping company, sorted by lost-in-shipping rate",
        "carriers.png",
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    plt.rcParams["font.family"] = "sans-serif"
    connection = psycopg2.connect(
        host=os.environ.get("PGHOST", "postgres"),
        port=int(os.environ.get("PGPORT", "5432")),
        dbname=os.environ.get("PGDATABASE", "funnel_analysis"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ.get("PGPASSWORD", "postgres"),
    )
    try:
        chart_funnel(read_analysis(connection, "q1_conversion_overall"))
        chart_conversion_by_cohort(read_analysis(connection, "q1_conversion_by_cohort"))
        chart_categories(read_analysis(connection, "q2_category_volumes"))
        chart_tiers(read_analysis(connection, "q3_tier_behavior"))
        chart_dropoffs(read_analysis(connection, "q4_dropoff_points"))
        chart_carriers(read_analysis(connection, "q4_carrier_losses"))
    finally:
        connection.close()


if __name__ == "__main__":
    main()
