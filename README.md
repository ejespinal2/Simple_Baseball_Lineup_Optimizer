# Baseball Lineup Optimizer

A Monte Carlo simulation tool for comparing the run-scoring potential of different batting lineups.

---

## How It Works

The optimizer uses a **Monte Carlo simulation** model. Each plate appearance is resolved by drawing a random number and mapping it against a player's historical per-PA rates (singles, doubles, triples, home runs, walks/HBP, and outs). Base-runner advancement follows a set of empirically-grounded probabilities — for example, a runner on second scores on a single roughly 58% of the time, and a runner on first takes an extra base on a single roughly 28% of the time. This process is repeated for every batter in the lineup across 9 innings, and then across thousands of simulated games, producing a distribution of runs scored that can be statistically compared between lineups.

---

## Required Input File

Provide a single `.csv` file containing one row per player. The file must include the following columns exactly as named:

| Column | Description |
|--------|-------------|
| `Player` | Player name — see formatting rules below |
| `AB` | At-bats |
| `H` | Hits |
| `X2B` | Doubles |
| `X3B` | Triples |
| `HR` | Home runs |
| `BB` | Walks |
| `HBP` | Hit by pitch |
| `SF` | Sacrifice flies |
| `SH` | Sacrifice hits (bunts) |
| `CS` | Caught stealing *(include column even if all zeros)* |

Singles (`X1B`) and all per-PA rates are derived automatically from these columns — do not add them manually.

---

## Player Name Format

Player names in the CSV **must** follow `Last, First` format, including the comma and a single space:

```
Doe, John
Smith, Alex
Rodriguez, Manuel
```

The names entered in your `Lineup1` / `Lineup2` tibbles must match the `Player` column in the CSV **exactly** — same spelling, same spacing, same capitalization. Any mismatch will be caught before the simulation runs and the offending name will be printed to help you correct it.

---

## Number of Simulations

Set `NO_GAMES` in the script to control how many games are simulated per lineup. The right number depends on how different the lineups are:

| Lineup Change | Recommended Simulations |
|---------------|------------------------|
| Drastic re-ordering (e.g. moving your best hitters significantly up or down) | 1,000 – 3,000 |
| Moderate changes (swapping 2–3 spots) | 3,000 – 5,000 |
| Subtle changes (swapping adjacent spots or similar hitters) | 5,000 – 10,000 |

The more similar two lineups are, the smaller the difference in mean runs will be, and the more simulations are needed to detect that difference with statistical confidence. If your p-value is borderline, try increasing `NO_GAMES` before drawing conclusions.

---

## Interpreting Results

The script prints the mean runs per game for each lineup and runs a **two-sample t-test** to determine whether the difference is statistically significant. A p-value below your chosen `P_THRESHOLD` (default `0.05`) means the difference is unlikely to be due to random variation alone. A p-value above it means there is not enough evidence to conclude one lineup is meaningfully better than the other.
