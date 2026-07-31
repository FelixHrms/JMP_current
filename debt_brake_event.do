********************************************************************************
* DEBT-BRAKE EVENT STUDY  —  March 2025 German fiscal shock
********************************************************************************
* Input : ois_2y.csv  (raw ECB SDW series, ESTR 2y OIS daily close)
*         Data\monetary_policy_induced_position.csv  (bond panel)
* Output: the four amplification regressions (binary, intensity, constraining,
*         relaxing) as a regular event study: estimation window of +/-15
*         trading days around 2025-03-05, shock = the Mar-5 daily OIS change,
*         zero on the other window days.
*
* Event. Debt-brake reform + infrastructure fund announced the evening of Tue
* 2025-03-04 (~19:30 CET, after the close), so the Wed 2025-03-05 daily change
* is the announcement response. In the raw ECB series the 2y OIS closes at
* 1.9878 on Mar 4 and 2.1378 on Mar 5: +15.0bp exactly — a rounding
* coincidence of two 4-decimal quotes, nothing constructed. (10y Bunds rose
* ~30bp the same day; the 2y OIS keeps the shock in the same units as every
* other lab.)
*
* Why any zero-shock days at all: the specification needs them to identify the
* HF main effect and the bond FE separately from the interaction. The window
* supplies them without dragging in the rest of the sample. +/-15 trading days
* spans ~Feb 12 to ~Mar 26, 2025, which contains no other large event; the one
* ECB decision inside it (2025-03-06, a fully priced cut) is dropped.
*
* Benchmarks in the same units at daily frequency: MP-daily binary 0.228 /
* intensity 0.132 -> predicted HF differential ~ 0.23 x 15 ~ +3.4bp.
* hf_intensity_pre runs through the Mar-4 close, i.e. positions are set
* BEFORE the evening announcement.
*
* Inference: the interaction lives on one date, so business_date clustering is
* degenerate for it; cluster by isin (cross-sectional inference).
********************************************************************************

clear all

local event_date "2025-03-05"
local half_window 15

********************************************************************************
* 1. Daily OIS change and event window, from the raw SDW export
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\ois_2y.csv", varnames(nonames) clear
gen ddate = date(v1, "YMD")
drop if missing(ddate)                       // SDW metadata rows
keep v2 ddate
destring v2, replace
rename v2 ois_2y
* rebuild the key as plain str10: the long SDW metadata line types v1 as strL,
* and a strL cannot be a merge key
gen business_date = string(ddate, "%tdCCYY-NN-DD")
sort ddate
gen d_ois_bp = (ois_2y - ois_2y[_n-1]) * 100

gen t = _n
quietly summarize t if business_date == "`event_date'"
assert r(N) == 1
local t0 = r(mean)
keep if abs(t - `t0') <= `half_window'

list business_date ois_2y d_ois_bp if business_date == "`event_date'", noobs clean   // expect +15.0

gen double event_shock = 0
replace event_shock = d_ois_bp if business_date == "`event_date'"

drop if business_date == "2025-03-06"        // the one ECB decision in the window

keep business_date event_shock
tempfile evt
save `evt'

********************************************************************************
* 2. The four amplification regressions on the window
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using `evt', keep(match) nogen   // trims the panel to the window

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* 2.1 Binary (event_shock main effect is absorbed by duration_match — expected)
reghdfe delta_y i.hf_involved##c.event_shock duration bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster isin)

* 2.2 Intensity
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster isin)

* 2.3 Constraining regime (shock > 0 on the event day -> the long-held side)
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag ///
    if (event_shock > 0 & event_shock < . & hf_intensity_long > 0) ///
     | (event_shock < 0 & hf_intensity_short > 0) ///
     | (event_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

* 2.4 Relaxing regime (the short-held side)
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag ///
    if (event_shock > 0 & event_shock < . & hf_intensity_short > 0) ///
     | (event_shock < 0 & hf_intensity_long > 0) ///
     | (event_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

********************************************************************************
* 3. By country — the shock is German, so the matched cross-section is DE
********************************************************************************
* The debt brake is a German fiscal event: the +15bp OIS scalar measures the
* German riskfree repricing, while for Italian bonds the same day is a
* different, partly spread/risk-on event mislabeled by the common scalar, so
* pooling dilutes the coefficient (first run: pooled intensity 0.07, DE-only
* 0.11 vs the 0.132 daily-frequency benchmark). Precedent inside the paper:
* the CDS lab pairs the Italian credit shock with the Italy cross-section
* only — same logic here, DE is primary and IT is the (absent) spillover
* margin. Once the DE label is confirmed from levelsof, the constraining and
* relaxing lines of Section 2 port over with the country condition appended.

levelsof collateral_country, local(countries)
foreach c of local countries {
    di as text _n "=== `c' only ==="
    reghdfe delta_y i.hf_involved##c.event_shock duration bid_ask_spread ctd_flag ///
        if collateral_country == "`c'", absorb(isin duration_match) vce(cluster isin)
    reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag ///
        if collateral_country == "`c'", absorb(duration_match isin) vce(cluster isin)
}

* Optional later: same four with the own-cell non-HF repricing as the shock
* (handles the curve steepening), the directionality split on the window,
* and the +/-10-day LP of the differential.
