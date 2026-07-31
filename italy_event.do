********************************************************************************
* ITALY EVENT STUDY  —  country-matched twin of the debt-brake event study
********************************************************************************
* Input : Data\monetary_policy_induced_position.csv  (bond panel; nothing else)
* Output: the four amplification regressions on an Italy-specific large shock,
*         estimation window +/-15 trading days, Italian bonds only.
*
* Event (default). 2022-07-14: M5S confidence-vote boycott and Draghi's
* resignation offer that evening — the largest Italy-specific yield day in
* the sample (10y BTP ~ +15-20bp; the list line below prints the realized
* value). Alternatives, switchable via the locals:
*   2023-09-28  NADEF deficit revision (announced evening 09-27; fiscal type,
*               closest analogue to the debt brake; ~ +10-15bp; set
*               ecb_in_window to 2023-09-14)
*   2023-11-20  Moody's outlook relief (Friday 11-17 after close; favorable
*               direction -> tests the relaxing side; ~ -10bp; no ECB day in
*               the window, set ecb_in_window to "")
*
* Shock scalar. Italy-specific events are spread events, so the 2y OIS is the
* wrong scalar. The shock is the day's MEAN delta_y of NON-HF Italian bonds —
* the realized repricing, computed from the panel itself (non-HF bonds only,
* so no mechanical endogeneity; no external data needed). For the cross-event
* comparison with Germany the units must match: re-run the debt-brake file
* with this same scalar construction (mean non-HF DE delta_y on 2025-03-05)
* instead of the OIS change — the per-OIS-bp DE coefficient is NOT comparable
* to the per-repricing-bp IT coefficient. Ledger ballpark in repricing units:
* MP intensity ~ 0.20. The CDS lab (0.107) is per CDS-bp — external check
* only, not unit-comparable without the CDS-to-yield pass-through.
*
* Window (Draghi default). +/-15 trading days spans ~Jun 23 to ~Aug 4 2022.
* The 2022-07-21 ECB day (first hike + TPI + the actual resignation) is
* dropped, and days +1 to +4 are dropped as well because the episode evolved
* over several days (continuation/reversal contamination of the controls) —
* this drop stays active for the alternative events too, harmless when the
* episode is one day.
*
* Inference: cluster by isin, as in the German file (single event date).
********************************************************************************

clear all

local event_date    "2022-07-14"
local ecb_in_window "2022-07-21"
local half_window   15

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* Italian bonds only: set the local to the Italy label EXACTLY as printed here
levelsof collateral_country
local italy "IT"
keep if collateral_country == "`italy'"

********************************************************************************
* 1. Event window and realized-repricing shock, from the panel itself
********************************************************************************

preserve
gen double dy0 = delta_y if hf_involved == 0
collapse (mean) event_scalar = dy0, by(business_date)
sort business_date
gen t = _n
quietly summarize t if business_date == "`event_date'"
assert r(N) == 1
local t0 = r(mean)
keep if abs(t - `t0') <= `half_window'

list business_date event_scalar if business_date == "`event_date'", noobs clean

gen double event_shock = 0
replace event_shock = event_scalar if business_date == "`event_date'"
quietly summarize event_shock if business_date == "`event_date'"
assert r(N) > 0 & r(mean) != 0 & r(mean) < .

drop if business_date == "`ecb_in_window'"
drop if inrange(t - `t0', 1, 4)              // continuation/reversal days out

keep business_date event_shock
tempfile evt
save `evt'
restore

merge m:1 business_date using `evt', keep(match) nogen   // trims to the window

********************************************************************************
* 2. The four amplification regressions
********************************************************************************

gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* 2.1 Binary
reghdfe delta_y i.hf_involved##c.event_shock duration bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster isin)

* 2.2 Intensity
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster isin)

* 2.3 Constraining regime (adverse events: the long-held side)
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag ///
    if (event_shock > 0 & event_shock < . & hf_intensity_long > 0) ///
     | (event_shock < 0 & hf_intensity_short > 0) ///
     | (event_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

* 2.4 Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.event_shock duration bid_ask_spread ctd_flag ///
    if (event_shock > 0 & event_shock < . & hf_intensity_short > 0) ///
     | (event_shock < 0 & hf_intensity_long > 0) ///
     | (event_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster isin)

* Binary-null note (applies to both event studies): the involved group is
* dominated by token hedged positions, so presence-without-size carries no
* differential on a single cross-section while sized positions do. The
* reportable resolution is the categorical-intensity spec (appendix
* machinery) on the window: a Q1-to-Q4 dose-response turns the binary null
* into evidence FOR the mechanism, not against it.
