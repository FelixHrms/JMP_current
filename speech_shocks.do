********************************************************************************
* SPEECH SHOCKS (EA-EMPD)  —  amplification with ECB communication surprises
********************************************************************************
* Input : Data\speech_shock.csv   (built by make_speech_shock.py from the
*         EA-EMPD, Altavilla-Gurkaynak-Kind-Laeven 2025: EB + President
*         speeches, 2y OIS window surprise in bp summed per trading day;
*         evening/non-trading-day events assigned to the next trading day;
*         GC meeting days carry speech_shock = missing and drop out)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Output: the four amplification regressions (binary, intensity,
*         constraining, relaxing) with speech shocks in place of MP shocks.
* Benchmarks (MP lab, same specs): binary 0.291, intensity 0.164,
* constraining 0.140, relaxing (Table VIII).
********************************************************************************

clear all

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\speech_shock.csv", clear
tempfile speech
save `speech'

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using `speech', keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* sanity: 494 speech days expected; GC days missing -> drop automatically
summarize speech_shock if n_speech_events > 0 & speech_shock < ., detail

* 1. Binary
reghdfe delta_y i.hf_involved##c.speech_shock duration bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster business_date isin)

* 2. Intensity
reghdfe delta_y c.log_hf_intensity##c.speech_shock duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3. Constraining regime
reghdfe delta_y c.log_hf_intensity##c.speech_shock duration bid_ask_spread ctd_flag ///
    if (speech_shock > 0 & speech_shock < . & hf_intensity_long > 0) ///
     | (speech_shock < 0 & hf_intensity_short > 0) ///
     | (speech_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 4. Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.speech_shock duration bid_ask_spread ctd_flag ///
    if (speech_shock > 0 & speech_shock < . & hf_intensity_short > 0) ///
     | (speech_shock < 0 & hf_intensity_long > 0) ///
     | (speech_shock == 0) ///
     | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
