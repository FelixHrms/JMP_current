********************************************************************************
* MACRO-RELEASE SHOCKS  —  first stage + amplification regressions
********************************************************************************
* Input : Data\release_shocks.csv        (built by build_release_shocks.ipynb)
*         Data\release_types_meta.csv    (release-type map: relevance, sigma, n)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Produces: first-stage gamma table, Data\macro_shock.csv,
*           release-shock amplification table (binary, intensity,
*           constraining regime, relaxing regime) + orthogonality test
********************************************************************************

clear all

********************************************************************************
* 1. First stage: daily 2y OIS change on standardised release surprises
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\release_shocks.csv", clear

* Regressor set: relevance >= 50, >= 10 release days in window, one print per
* simultaneous bundle (flash-CPI trio, GDP QoQ/YoY, retail MoM/YoY, IP MoM/YoY,
* PMI composite = derived from Mfg + Services). Full map: release_types_meta.csv.
* Robustness: replace the list with s_* (fitted value barely moves; individual
* gammas inside bundles are not separately interpretable).
* ECB monetary event days are excluded: those days keep the EA-MPD shock.
* The 38 in-window ecb_day flags must line up with the paper's EA-MPD events.
reg d_ois2y_bp                                                ///
    s_eccpest      s_cpexemuy_p   s_eccpemuy_f                /// CPI: flash headline YoY, flash core YoY, final headline YoY
    s_mpmiezma_p   s_mpmiezsa_p                               /// PMI flash: manufacturing, services
    s_mpmiezma_f   s_mpmiezsa_f                               /// PMI final: manufacturing, services
    s_eugnemuq_a   s_eugnemuq_f                               /// GDP QoQ: advance, final
    s_umrtemu      s_euccemu_p                                /// unemployment rate, consumer confidence flash
    s_euitemum     s_rssaemum                                 /// industrial production MoM, retail sales MoM
    s_euppemuy     s_ecmam3yy                                 /// PPI YoY, M3 YoY
    if ecb_day == 0, vce(robust)

* Daily macro shock (bp) = fitted news component, net of the constant
predict macro_shock, xb
replace macro_shock = macro_shock - _b[_cons]
replace macro_shock = 0 if n_releases == 0
replace macro_shock = . if ecb_day == 1

* sanity: distribution of the shock on release days
summarize macro_shock if n_releases > 0 & ecb_day == 0, detail

rename date business_date
keep business_date macro_shock
export delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.csv", replace
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", replace

********************************************************************************
* 2. Merge into the bond panel
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* keep(match): drops panel days outside the release-shock coverage
* (before 2021-01-05 / after 2025-10-23). ECB days merge with macro_shock
* missing and fall out of the regressions automatically.
* Requires Section 1 to have been run once (creates macro_shock.dta).
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

********************************************************************************
* 3. Amplification regressions (release-shock analogue of the MP baseline)
********************************************************************************

* 3.1 Baseline regression
reghdfe delta_y i.hf_involved##c.macro_shock duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag ///
    if (macro_shock > 0 & macro_shock < . & hf_intensity_long > 0) ///
 | (macro_shock < 0 & hf_intensity_short > 0) ///
 | (macro_shock == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag ///
    if (macro_shock > 0 & macro_shock < . & hf_intensity_short > 0) ///
    | (macro_shock < 0 & hf_intensity_long > 0) ///
	| (macro_shock == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3.2 Shock-size terciles (non-linearity within the release laboratory)
* Day-level tercile cutoffs of |macro_shock| across nonzero release days;
* tercile 0 = zero-shock days. T1/T2 shocks are tiny by construction (the
* shock distribution is quasi-sparse), so their slopes carry wide CIs; the
* informative comparison is T3 vs T1/T2 and vs the pooled estimate.
egen day_tag = tag(business_date)
xtile terc_day = abs(macro_shock) if day_tag == 1 & macro_shock != 0 & macro_shock < ., nq(3)
egen shock_tercile = max(terc_day), by(business_date)
replace shock_tercile = 0 if macro_shock == 0
drop day_tag terc_day

* explicit interaction variables (a triple factor interaction makes the
* equality tests fragile to coefficient naming; this is equivalent).
* Binary analogue: swap log_hf_intensity for hf_involved.
gen hf_t1 = log_hf_intensity * (shock_tercile == 1)
gen hf_t2 = log_hf_intensity * (shock_tercile == 2)
gen hf_t3 = log_hf_intensity * (shock_tercile == 3)
gen hfshock_t1 = log_hf_intensity * macro_shock * (shock_tercile == 1)
gen hfshock_t2 = log_hf_intensity * macro_shock * (shock_tercile == 2)
gen hfshock_t3 = log_hf_intensity * macro_shock * (shock_tercile == 3)

reghdfe delta_y c.log_hf_intensity hf_t1 hf_t2 hf_t3 hfshock_t1 hfshock_t2 hfshock_t3 ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test hfshock_t1 == hfshock_t3
test (hfshock_t1 == hfshock_t2) (hfshock_t2 == hfshock_t3)

* continuous convexity check: does the amplification per bp rise with |shock|?
* hfshock_size > 0 => convex; = 0 => the amplification share is size-invariant.
gen hfshock      = log_hf_intensity * macro_shock
gen hf_size      = log_hf_intensity * abs(macro_shock)
gen hfshock_size = log_hf_intensity * macro_shock * abs(macro_shock)

reghdfe delta_y c.log_hf_intensity hf_size hfshock hfshock_size ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* 4. Orthogonality of HF positioning to the release shock
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(match) nogen

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) macro_shock (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to release days and test orthogonality
keep if macro_shock != 0 & !missing(macro_shock)
reg macro_shock lag_net_pos, robust
