********************************************************************************
* MACRO-RELEASE SHOCKS  —  first stage + amplification regressions
********************************************************************************
* Input : Data\release_shocks.csv        (built by build_release_shocks.ipynb)
*         Data\release_types_meta.csv    (release-type map: relevance, sigma, n)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Produces: first-stage gamma table, Data\macro_shock.csv,
*           release-shock amplification table (binary, intensity,
*           constraining regime, relaxing regime) + yield-denominated IV
*           (unit-comparable to the MP laboratory) + orthogonality test
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
predict double macro_shock, xb
replace macro_shock = macro_shock - _b[_cons]
* exact zero for days whose releases all fall outside the regressor set:
* float dust from the constant subtraction otherwise counts as a "nonzero"
* shock and lands in tercile 1 (1e-9-sized regressor -> degenerate estimates)
replace macro_shock = 0 if abs(macro_shock) < 1e-6
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

* 3.2 Decomposing release days a la Jarocinski-Karadi (poor man's sign split)
* Classify each release day by the comovement of the release shock and the
* EuroStoxx 50 return: opposite signs -> discount-rate-type news (yields up,
* stocks down); same sign -> growth-type news. Mirrors the paper's JK table
* for ECB events, applied within the release laboratory. Both components in
* one specification (they live on disjoint days) + Wald test of equality.
* eurostoxx50.csv is the ECB SDW export (reverse-chronological, header rows).

preserve
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\eurostoxx50.csv", clear varnames(nonames)
keep v1 v2
gen ddate = date(v1, "YMD")
drop if missing(ddate)
destring v2, replace force
sort ddate
gen double eq_ret = 100 * (v2 / v2[_n-1] - 1)
gen business_date = string(ddate, "%tdCCYY-NN-DD")
keep business_date eq_ret
tempfile stoxx
save `stoxx'
restore

foreach v in eq_ret disc_day growth_day shock_disc shock_growth comp_type ///
    hfb_disc hfb_gro hfi_disc hfi_gro {
    capture drop `v'
}
merge m:1 business_date using `stoxx', keep(master match) nogen

* guards required: in Stata a missing product compares as +inf, so an
* unmatched equity day would silently classify as growth-type without them
gen byte disc_day   = (macro_shock * eq_ret < 0) if !missing(macro_shock, eq_ret)
gen byte growth_day = (macro_shock * eq_ret > 0) if !missing(macro_shock, eq_ret)
gen double shock_disc   = macro_shock * disc_day
gen double shock_growth = macro_shock * growth_day

* composition: day counts and |shock| by component (balance check)
gen comp_type = .
replace comp_type = 1 if disc_day == 1
replace comp_type = 2 if growth_day == 1
label define comp 1 "discount-type" 2 "growth-type", replace
label values comp_type comp
egen day_tag = tag(business_date)
gen double abs_ms = abs(macro_shock)
tabstat abs_ms if day_tag & comp_type < ., by(comp_type) stat(n mean p50 max)
drop day_tag abs_ms

* binary (mirrors the paper's JK table) and intensity variants
gen double hfb_disc = hf_involved * shock_disc
gen double hfb_gro  = hf_involved * shock_growth
gen double hfi_disc = log_hf_intensity * shock_disc
gen double hfi_gro  = log_hf_intensity * shock_growth

reghdfe delta_y i.hf_involved hfb_disc hfb_gro ///
    duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
test hfb_disc == hfb_gro

reghdfe delta_y c.log_hf_intensity hfi_disc hfi_gro ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test hfi_disc == hfi_gro

* the sign classification is only meaningful where the release dominates the
* day's equity move (sub-1bp shocks are classified by noise, and random
* misclassification pulls the two components together). Repeat on plateau
* days only, zero-shock days retained as the baseline.
reghdfe delta_y i.hf_involved hfb_disc hfb_gro ///
    duration bid_ask_spread ctd_flag ///
    if macro_shock == 0 | (abs(macro_shock) > 1 & macro_shock < .), ///
    absorb(isin duration_match) vce(cluster business_date isin)
test hfb_disc == hfb_gro

reghdfe delta_y c.log_hf_intensity hfi_disc hfi_gro ///
    duration bid_ask_spread ctd_flag ///
    if macro_shock == 0 | (abs(macro_shock) > 1 & macro_shock < .), ///
    absorb(duration_match isin) vce(cluster business_date isin)
test hfi_disc == hfi_gro

********************************************************************************
* 3.3 Yield-denominated IV: amplification per bp of realized market repricing
********************************************************************************
* Purpose: cross-laboratory unit comparability. The OLS interaction is "extra
* bp per bp of OIS-measured shock", so its level inherits the shock's
* pass-through into sovereign yields (~0.6 on release days vs ~0.8 on MP days)
* and, for MP, the intraday-vs-daily frequency wedge. Fix by rescaling inside
* the estimator: endogenous regressor = HF x realized cell repricing (cell
* mean of NON-HF bond yield changes), instrument = HF x shock. The baseline
* is then 1 by construction in every laboratory (the market move IS the
* regressor) and the interaction reads "extra bp per bp of realized repricing
* of comparable non-HF bonds". Exactly identified -> IV point estimate =
* reduced-form interaction / first-stage pass-through, with correct SEs.
* Two artifacts die in this ratio:
*   (i)  shock-denomination (pass-through) differences across laboratories;
*   (ii) measurement error in the instrument (daily vs intraday shock EIV
*        attenuates numerator and denominator equally, so it cancels).
* No mechanical endogeneity: the interaction is exactly zero for every bond
* entering the cell mean (non-HF bonds have hf_involved = 0 and
* log_hf_intensity = 0), and the cell-mean main effect is absorbed by the
* duration_match FE. Cell-mean sampling noise sits in the endogenous
* regressor, uncorrelated with the instrument -> handled by the IV itself.
* First stage is strong here because of the ~600 shock-day clusters (report
* the KP F); this is why the release laboratory carries the IV better than
* the 38-event MP laboratory or the 41-day tail set.
* Requires (once): ssc install ivreghdfe ivreg2 ranktest ftools

* realized market repricing: cell mean over non-HF bonds with observed dy
egen double sum_nhf = total(cond(hf_involved == 0 & !missing(delta_y), delta_y, 0)), by(duration_match)
egen double n_nhf   = total(hf_involved == 0 & !missing(delta_y)), by(duration_match)
gen double mkt_repr = sum_nhf / n_nhf if n_nhf >= 1
count if missing(mkt_repr)   // bonds in cells with no non-HF benchmark (drop out)

* endogenous interactions and instruments
gen double hfb_M   = hf_involved      * mkt_repr
gen double hfi_M   = log_hf_intensity * mkt_repr
gen double hfb_s   = hf_involved      * macro_shock
gen double hfi_s   = log_hf_intensity * macro_shock
gen double hfb_ois = hf_involved      * ois_2y
gen double hfi_ois = log_hf_intensity * ois_2y

* (a) release laboratory (ECB days drop automatically: macro_shock missing)
ivreghdfe delta_y hf_involved duration bid_ask_spread ctd_flag ///
    (hfb_M = hfb_s), absorb(isin duration_match) cluster(business_date isin)
ivreghdfe delta_y log_hf_intensity duration bid_ask_spread ctd_flag ///
    (hfi_M = hfi_s), absorb(duration_match isin) cluster(business_date isin)

* (b) MP laboratory through the IDENTICAL pipeline (instrument = intraday
* EA-MPD surprise, zero on non-MP days -> identification from MP days with
* all other days as shared baseline). THESE are the benchmark numbers the
* release column is compared to - not the per-OIS-bp OLS coefficients.
ivreghdfe delta_y hf_involved duration bid_ask_spread ctd_flag ///
    (hfb_M = hfb_ois), absorb(isin duration_match) cluster(business_date isin)
ivreghdfe delta_y log_hf_intensity duration bid_ask_spread ctd_flag ///
    (hfi_M = hfi_ois), absorb(duration_match isin) cluster(business_date isin)

* (c) pooled two-laboratory IV + Wald test of equality. Day-type split by
* nonzero shock; release instrument zeroed (not missing) on ECB days so MP
* days stay in the sample; days with neither shock enter both labs' baseline.
gen byte rel_day = (macro_shock != 0 & !missing(macro_shock))
gen byte mp_day  = (ois_2y != 0 & !missing(ois_2y))
gen double hfb_s0 = hf_involved      * cond(missing(macro_shock), 0, macro_shock)
gen double hfi_s0 = log_hf_intensity * cond(missing(macro_shock), 0, macro_shock)
gen double hfb_M_rel = hfb_M * rel_day
gen double hfb_M_mp  = hfb_M * mp_day
gen double hfi_M_rel = hfi_M * rel_day
gen double hfi_M_mp  = hfi_M * mp_day

ivreghdfe delta_y hf_involved duration bid_ask_spread ctd_flag ///
    (hfb_M_rel hfb_M_mp = hfb_s0 hfb_ois), absorb(isin duration_match) cluster(business_date isin)
test hfb_M_rel = hfb_M_mp

ivreghdfe delta_y log_hf_intensity duration bid_ask_spread ctd_flag ///
    (hfi_M_rel hfi_M_mp = hfi_s0 hfi_ois), absorb(duration_match isin) cluster(business_date isin)
test hfi_M_rel = hfi_M_mp

* (d) like-for-like: releases vs the MP INFORMATION component (JK), all in
* realized-repricing units. Releases are information-type news, so the valid
* same-type benchmark inside the MP lab is cbi_pm, not the pooled surprise.
* Three-way pooled IV: release days / pure-monetary MP days / information MP
* days, each with its own instrument. The three Wald tests read:
*   rel = inf : the comparability claim (same type -> same magnitude)
*   rel = mon : the type gradient seen from the release side
*   mon = inf : the paper's JK gradient replicated in clean units
* Power caveat: the information events are a subset of the 38 MP days ->
* few clusters behind the inf instrument; check the KP F before reading the
* tests (reduced-form Table-jk SEs suggest it is feasible: 0.113, se 0.042).
count if mp_pm != 0 & cbi_pm != 0 & !missing(mp_pm, cbi_pm)
* ^ must be 0: poor-man's JK assigns each event wholly to one component, so
*   the components live on disjoint days. If nonzero, the day-split below is
*   invalid -> use the sample-split fallback at the end of this block.
gen byte mon_day = (mp_pm  != 0 & !missing(mp_pm))
gen byte inf_day = (cbi_pm != 0 & !missing(cbi_pm))
gen double hfb_mpp = hf_involved      * mp_pm
gen double hfb_cbi = hf_involved      * cbi_pm
gen double hfi_mpp = log_hf_intensity * mp_pm
gen double hfi_cbi = log_hf_intensity * cbi_pm
gen double hfb_M_mon = hfb_M * mon_day
gen double hfb_M_inf = hfb_M * inf_day
gen double hfi_M_mon = hfi_M * mon_day
gen double hfi_M_inf = hfi_M * inf_day

ivreghdfe delta_y hf_involved duration bid_ask_spread ctd_flag ///
    (hfb_M_rel hfb_M_mon hfb_M_inf = hfb_s0 hfb_mpp hfb_cbi), ///
    absorb(isin duration_match) cluster(business_date isin)
test hfb_M_rel = hfb_M_inf
test hfb_M_rel = hfb_M_mon
test hfb_M_mon = hfb_M_inf

ivreghdfe delta_y log_hf_intensity duration bid_ask_spread ctd_flag ///
    (hfi_M_rel hfi_M_mon hfi_M_inf = hfi_s0 hfi_mpp hfi_cbi), ///
    absorb(duration_match isin) cluster(business_date isin)
test hfi_M_rel = hfi_M_inf
test hfi_M_rel = hfi_M_mon
test hfi_M_mon = hfi_M_inf

* fallback (also the robustness if the disjointness count above is nonzero):
* information-benchmark IV with pure-monetary event days DROPPED from the
* sample, so no mp_pm variation needs instrumenting. Compare the coefficient
* on hfb_M / hfi_M here directly with the release column in block (a).
ivreghdfe delta_y hf_involved duration bid_ask_spread ctd_flag ///
    (hfb_M = hfb_cbi) if mon_day == 0, absorb(isin duration_match) cluster(business_date isin)
ivreghdfe delta_y log_hf_intensity duration bid_ask_spread ctd_flag ///
    (hfi_M = hfi_cbi) if mon_day == 0, absorb(duration_match isin) cluster(business_date isin)

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
