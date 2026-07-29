"""Build Data/speech_shock.csv from the EA-EMPD (Altavilla, Gurkaynak, Kind,
Laeven 2025) speech events.

Construction decisions:
- Events kept: Event_type EB and P (Executive Board / President speeches).
  GC_ME/GC_PR/GC_PC are excluded -- Governing Council days are the paper's
  existing MP laboratory.
- Shock = OIS_2Y window surprise (bp), same units as the paper's MP shock.
  Events with missing OIS_2Y are dropped (counted below).
- Day assignment to the daily bond panel (delta_y is close-to-close):
  events at hour >= 18 CET or on non-trading days are assigned to the NEXT
  trading day (their market reaction is in the next close-to-close change);
  everything else (incl. pre-open morning events) to the same trading day.
  Borderline: 17h events (64) stay same-day; noted as a caveat.
- Multiple events per assigned day are SUMMED (net daily communication news).
- Days assigned to an ECB Governing Council day carry speech_shock = missing
  so they drop from the regressions (contamination; mirrors the release lab).
- Trading calendar and ecb_day flags come from Data/release_shocks.csv.
"""
import pandas as pd
import numpy as np

events = pd.read_excel("EA-EMPD.xlsx", sheet_name="EA-EMPD")
events["Date_time"] = pd.to_datetime(events["Date_time"])

cal = pd.read_csv("Data/release_shocks.csv", usecols=["date", "ecb_day"])
cal["date"] = pd.to_datetime(cal["date"])
cal = cal.sort_values("date").reset_index(drop=True)
caldates = cal["date"].values

sp = events[
    events["Event_type"].isin(["EB", "P"])
    & (events["Date_time"] >= "2020-12-15")
].copy()
n_all = len(sp)
sp = sp.dropna(subset=["OIS_2Y"])
print(f"speech events in window: {n_all}, dropped for missing OIS_2Y: {n_all - len(sp)}")

# target calendar date: next day if evening or non-trading day
shift = (sp["Date_time"].dt.hour >= 18) | (sp["Non_regular_trading_day"] == 1)
target = sp["Date_time"].dt.normalize() + pd.to_timedelta(shift.astype(int), unit="D")
print(f"events shifted to next day (evening/non-trading): {int(shift.sum())}")

# snap to first trading day >= target
idx = np.searchsorted(caldates, target.values, side="left")
in_cal = idx < len(caldates)
sp, idx = sp[in_cal], idx[in_cal]
sp["business_date"] = caldates[idx]
print(f"events beyond calendar end (dropped): {int((~in_cal).sum())}")

daily = (
    sp.groupby("business_date")
    .agg(speech_shock=("OIS_2Y", "sum"), n_speech_events=("OIS_2Y", "size"))
    .reset_index()
)

out = cal.rename(columns={"date": "business_date"}).merge(daily, on="business_date", how="left")
out["n_speech_events"] = out["n_speech_events"].fillna(0).astype(int)
out["speech_shock"] = out["speech_shock"].fillna(0.0)
out.loc[out["ecb_day"] == 1, "speech_shock"] = np.nan  # GC days: drop from lab

ev = out[(out["n_speech_events"] > 0) & out["speech_shock"].notna()]
print(f"trading days: {len(out)}, speech days: {len(ev)}, "
      f"speech days lost to GC overlap: {int(((out['n_speech_events'] > 0) & out['speech_shock'].isna()).sum())}")
print("speech_shock on speech days (bp):")
print(ev["speech_shock"].describe().round(3).to_string())
print("|shock| quantiles:", ev["speech_shock"].abs().quantile([0.5, 0.9, 0.99]).round(2).tolist())

out["business_date"] = out["business_date"].dt.strftime("%Y-%m-%d")
out[["business_date", "speech_shock", "n_speech_events"]].to_csv("Data/speech_shock.csv", index=False)
print("written: Data/speech_shock.csv")
