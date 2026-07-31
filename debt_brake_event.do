********************************************************************************
* DEBT-BRAKE EVENT STUDY  —  March 2025 German fiscal shock, single event
********************************************************************************
* Input : Data\release_shocks.csv  (daily 2y OIS + ecb_day flags, from notebook)
*         Data\monetary_policy_induced_position.csv  (bond panel)
* Output: the four amplification regressions (binary, intensity, constraining,
*         relaxing) with the 2025-03-05 debt-brake repricing as the only
*         nonzero shock, in two unit systems (Sections 2 and 3).
*
* Event. CDU/CSU-SPD debt-brake reform + infrastructure-fund announcement,
* evening of Tue 2025-03-04 (~19:30 CET, after the cash close), so the Wed
* 2025-03-05 daily change is the announcement response. 2y OIS +15.0bp on the
* day; 10y Bunds ~ +30bp (largest one-day rise since 1990). A supply/term-
* premium shock that steepened the curve — hence two unit systems:
*   Section 2: per bp of daily 2y OIS. Benchmark: MP re-measured at DAILY
*     frequency (same units, same outcome window): binary 0.228 / intensity
*     0.132. Stated prediction: HF differential ~ 0.23 x 15 ~ +3.4bp, at or
*     below that in the low-directionality 2025 positioning regime.
*   Section 3: per bp of the OWN CELL's realized non-HF repricing (steepener-
*     robust; the denominator is the market's own move, so no pass-through or
*     frequency adjustment applies). Ledger benchmark in these units: MP
*     binary ~ 0.36 / intensity ~ 0.20.
*
* Design. Single-event version of the tail/EMPD labs: full panel, shock = 0 on
* all non-event days, so bond FE and the HF main effect are identified panel-
* wide and the interaction is identified from the event cross-section alone.
* ECB days carry shock = . and drop out — the 2025-03-06 ECB cut (fully
* priced) exits by this rule. hf_intensity_pre is measured through the Mar-4
* close, i.e. BEFORE the evening announcement, and the announcement timing was
* political (coalition talks) — clean exogeneity. Minor EA releases on Mar 5
* contribute ~1-2bp of fitted macro news per the release first stage — second
* order against 15bp, ignored.
*
* Inference. The interaction lives on ONE date, so business_date clustering is
* degenerate for it; cluster by isin (cross-sectional inference, standard for
* single-event studies). duration_match FE absorb the common day move at the
* duration x country level. n=1 discipline: this validates the pooled share
* out of sample at ~2x the largest MP surprise — it does not replace it.
********************************************************************************

clear all

local event_date "2025-03-05"

********************************************************************************
* 1. Event shock series (daily 2y OIS units)
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\release_shocks.csv", clear
keep date d_ois2y_bp ecb_day
rename date business_date

gen double event_shock = 0
replace event_shock = d_ois2y_bp if business_date == "`event_date'"
replace event_shock = .          if ecb_day == 1   // ECB days out (incl. 2025-03-06)

list business_date d_ois2y_bp if business_date == "`event_date'", noobs clean   // expect +15.0

keep business_date event_shock
tempfile evt
save `evt'

********************************************************************************
* 2. Four amplification regressions, per bp of 2y OIS
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using `evt', keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* guard: the event day is in the panel and carries the +15bp shock
quietly summarize event_shock if business_date == "`event_date'"
assert r(N) > 0 & r(mean) != 0 & r(mean) < .

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
* 3. Same four, per bp of realized cell repricing (steepener-robust units)
********************************************************************************
* Denominator = mean delta_y of NON-HF bonds in the bond's own duration x
* country cell on the event day (the Section-3.3 construction from
* release_shocks.do, as OLS reduced form). No mechanical endogeneity: every
* bond entering the cell mean has a zero interaction regressor. Cells without
* any non-HF bond drop out. Diagnostic first — the curve/country profile of
* the event itself (expect the steepener: short end ~ +15, 10y ~ +30).

preserve
keep if business_date == "`event_date'" & hf_involved == 0
collapse (mean) delta_y (count) n_bonds = delta_y, by(duration_bin collateral_country)
list, noobs clean
restore

egen double cell_rep = mean(cond(hf_involved == 0, delta_y, .)), by(duration_match)
gen double event_rep = 0 if !missing(event_shock)
replace event_rep = cell_rep if business_date == "`event_date'" & !missing(event_shock)
drop cell_rep

* 3.1 Binary
reghdfe delta_y i.hf_involved##c.event_rep duration bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster isin)

* 3.2 Intensity
reghdfe delta_y c.log_hf_intensity##c.event_rep duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster isin)

* 3.3 Constraining regime
reghdfe delta_y c.log_hf_intensity##c.event_rep duration bid_ask_spread ctd_flag ///
    if (event_rep > 0 & event_rep < . & hf_intensity_long > 0) ///
     | (event_rep < 0 & hf_intensity_short > 0) ///
     | (event_rep == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

* 3.4 Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.event_rep duration bid_ask_spread ctd_flag ///
    if (event_rep > 0 & event_rep < . & hf_intensity_short > 0) ///
     | (event_rep < 0 & hf_intensity_long > 0) ///
     | (event_rep == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

* Next (separate, only if the four lines validate): event-window LP of the HF
* differential over Mar 5 +/- 10 days (differential reverts while the level
* shift stays) and the directionality split — both reuse existing machinery.
