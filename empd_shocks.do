********************************************************************************
* EA-EMPD SHOCKS  —  amplification with GC monetary events + ECB speeches
********************************************************************************
* Input : Data\empd_shock.csv   (built by build_empd_shocks.ipynb from the
*         EA-EMPD, Altavilla-Gurkaynak-Kind-Laeven 2025: GC_ME monetary-event
*         windows POOLED with EB + President speeches; 2y OIS window surprise
*         in bp summed per trading day; evening/non-trading-day events
*         assigned to the next trading day. Self-contained build: calendar
*         from ois_2y.csv, no release-pipeline inputs. The csv runs to
*         mid-2026; keep(match) trims to the panel window -> 532 in-panel
*         event days = 38 GC days [validated 1:1 against the paper's EA-MPD
*         events] + 494 speech days)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Output: the four amplification regressions (binary, intensity,
*         constraining, relaxing) on the pooled communication-shock series.
* Benchmarks (MP-only lab, same specs, intraday shock — directly comparable
* units): binary 0.291, intensity 0.164, constraining 0.140, relaxing
* (Table VIII).
********************************************************************************

clear all

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\empd_shock.csv", clear
tempfile empd
save `empd'

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using `empd', keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* sanity: 532 event days expected (38 GC + 494 speech)
summarize empd_shock if n_empd_events > 0, detail

* 1. Binary
reghdfe delta_y i.hf_involved##c.empd_shock duration bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster business_date isin)

* 2. Intensity
reghdfe delta_y c.log_hf_intensity##c.empd_shock duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3. Constraining regime
reghdfe delta_y c.log_hf_intensity##c.empd_shock duration bid_ask_spread ctd_flag ///
    if (empd_shock > 0 & empd_shock < . & hf_intensity_long > 0) ///
     | (empd_shock < 0 & hf_intensity_short > 0) ///
     | (empd_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 4. Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.empd_shock duration bid_ask_spread ctd_flag ///
    if (empd_shock > 0 & empd_shock < . & hf_intensity_short > 0) ///
     | (empd_shock < 0 & hf_intensity_long > 0) ///
     | (empd_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
