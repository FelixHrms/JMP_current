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
*         constraining, relaxing) on the pooled communication-shock series,
*         plus threshold-existence and plateau tests (size_profile template).
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

* 0. Baseline pass-through check (no FE, mirrors Table IV col 1): the shock
* main effect is absorbed by duration_match in everything below, so THIS is
* the column where the empd baseline is visible (MP benchmark ~0.8-1).
reghdfe delta_y i.hf_involved##c.empd_shock, vce(cluster business_date isin)

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

********************************************************************************
* 5. Threshold existence, robust to the small-shock cutoff
********************************************************************************
* Two-slope specification per cutoff c (size_profile template): report
* (a) beta_small = 0 (dead zone) and (b) beta_small = beta_large (existence,
* rejecting pure proportionality) for every c - existence without location.
* The speech events supply the small-shock support (median |shock| 0.67bp).
* READING: similar slopes with (b) not rejected = the share is proportional
* down to sub-bp shocks (scale-invariance - the constant-leverage prediction).
* An insignificant beta_small on its own is NOT evidence of a dead zone: the
* small side has little identifying variance against the ~3bp daily yield
* noise, so its CI covers zero AND the plateau. Only rejection of (b) with
* beta_small ~ 0 would establish a threshold.

foreach c of numlist 0.5 0.75 1 1.5 2 {
    gen double hfd_small = log_hf_intensity * (abs(empd_shock) <= `c' & empd_shock != 0)
    gen double hfd_large = log_hf_intensity * (abs(empd_shock) >  `c')
    gen double hfS_small = log_hf_intensity * empd_shock * (abs(empd_shock) <= `c')
    gen double hfS_large = log_hf_intensity * empd_shock * (abs(empd_shock) >  `c')

    di as text _n "================ cutoff c = `c' bp ================"
    reghdfe delta_y c.log_hf_intensity hfd_small hfd_large hfS_small hfS_large ///
        duration bid_ask_spread ctd_flag, absorb(duration_match isin) ///
        vce(cluster business_date isin)
    test hfS_small == 0                    // (a) dead zone: zero amplification
    test hfS_small == hfS_large            // (b) below the plateau (existence)

    drop hfd_small hfd_large hfS_small hfS_large
}

********************************************************************************
* 6. Plateau: flatness above the (unpinned) threshold region
********************************************************************************
* Conditional on |shock| > 1bp (representative cutoff; Section 5 shows results
* do not hinge on it): convexity term tests whether the per-bp amplification
* rises with size within the plateau. hfS_size = 0 -> flat share.
* The size term is CENTERED at the mean |shock| of large-shock days: without
* centering, hfS_size = hfS_large x |shock| is ~0.95 correlated with
* hfS_large and every individual t collapses mechanically. Centered,
* hfS_large is the per-bp slope at the average large shock and hfS_size the
* convexity around it; read the individual convexity test AND the joint test.

egen day_tag = tag(business_date)
gen double abs_empd = abs(empd_shock)
quietly summarize abs_empd if day_tag & abs_empd > 1
scalar mean_large = r(mean)
di as text "mean |shock| on large-shock days: " mean_large

gen double hfd_large = log_hf_intensity * (abs_empd > 1)
gen double hfS_large = log_hf_intensity * empd_shock * (abs_empd > 1)
gen double hfS_size  = log_hf_intensity * empd_shock * (abs_empd - mean_large) * (abs_empd > 1)

reghdfe delta_y c.log_hf_intensity hfd_large hfS_large hfS_size ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) ///
    vce(cluster business_date isin)
test hfS_size == 0                 // convexity: 0 -> flat share on the plateau
test hfS_large == 0                // slope at the mean large shock
test (hfS_large == 0) (hfS_size == 0)   // joint
