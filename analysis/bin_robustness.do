********************************************************************************
* ALTERNATIVE DURATION BIN WIDTHS
* Input   : Data\monetary_policy_induced_position.csv
* Produces: Appendix table with the four main specifications (binary,
*           continuous, constraining, relaxing) under 1-year and 3-year
*           duration bins (baseline: 2-year), plus within-cell duration
*           dispersion statistics for each bin width (1y / 2y / 3y).
* Mirrors the specifications of appendix_robustness.do Table A1.
********************************************************************************

clear all

* 1. Import the data (once; bins are regenerated per width below)
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

gen log_hf_intensity = log(1 + hf_intensity_pre)

********************************************************************************
* 2. Within-cell duration dispersion, by bin width (incl. the 2y baseline)
*    Reported per cell: SD of duration (missing for single-bond cells) and
*    number of bonds. For the appendix text sentence.
********************************************************************************

foreach w in 1 2 3 {

    di as text _n "================ dispersion, `w'-year bins ================"

    cap drop duration_bin duration_match
    gen duration_bin = floor(duration / `w') * `w'
    gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

    preserve
        collapse (sd) cell_sd=duration (count) cell_n=duration, by(duration_match)
        quietly count
        di as text "cells total          : " as result r(N)
        quietly count if cell_n >= 2
        di as text "cells with >=2 bonds : " as result r(N)
        summarize cell_n, detail
        summarize cell_sd, detail
    restore
}

********************************************************************************
* 3. The four main specifications under 1-year and 3-year bins
*    (identical to the A1 specifications, only the bin width changes)
********************************************************************************

foreach w in 1 3 {

    di as text _n "================ regressions, `w'-year bins ================"

    cap drop duration_bin duration_match
    gen duration_bin = floor(duration / `w') * `w'
    gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

    * (1) Binary
    reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, ///
        absorb(isin duration_match) vce(cluster business_date isin)

    * (2) Continuous intensity
    reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, ///
        absorb(duration_match isin) vce(cluster business_date isin)

    * (3) Constraining regime
    reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
        if (ois_2y > 0 & hf_intensity_long > 0) ///
     | (ois_2y < 0 & hf_intensity_short > 0) ///
     | (ois_2y == 0) ///
     | (hf_intensity_pre == 0), ///
        absorb(duration_match isin) vce(cluster business_date isin)

    * (4) Relaxing regime
    reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
        if (ois_2y > 0 & hf_intensity_short > 0) ///
        | (ois_2y < 0 & hf_intensity_long > 0) ///
        | (ois_2y == 0) ///
        | (hf_intensity_pre == 0), ///
        absorb(duration_match isin) vce(cluster business_date isin)
}
