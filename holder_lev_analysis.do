********************************************************************************
* HOLDER-WEIGHTED HF LEVERAGE AND YIELD AMPLIFICATION
* holder_leverage is the holdings-weighted leverage of a bond's HF holders, built
* as -(|net|-weighted mean |repo haircut|): higher = more leveraged (less own
* capital posted per unit of exposure). It varies across bonds within a day, so the
* tests are identified within day, free of the cycle, exactly like holder_dir.
* HYPOTHESIS: more leveraged holders face larger capital erosion per unit price move
* (dE/E = (1/m) x dP/P), so they rebalance more and AMPLIFY MORE. Expected signs
* mirror the directionality exercise: the triple interaction is POSITIVE and the
* high-leverage group amplifies MORE than the low-leverage group.
* NOTE: every fund here is a hedge fund, so the contrast is HF-held-low-leverage vs
* HF-held-high-leverage, against a baseline of bonds with no HF activity.
********************************************************************************
clear all
set more off

capture log close
log using "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Code/holder_lev_analysis.log", replace text

*===============================================================================
* 1. IMPORT
*===============================================================================
import delimited "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Data/monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* Panel setup (sequential day counter per bond, robust to calendar gaps)
egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time


*===============================================================================
* 2. CREATE THE MEASURE
*===============================================================================
* Predetermine holder_leverage: 5-day trailing mean over the prior ACTIVE days only
* (idle days are missing and skipped, so they do not pull the average).
gen hl_sum = 0
gen hl_cnt = 0
forvalues k = 1/5 {
    replace hl_sum = hl_sum + L`k'.holder_leverage if !missing(L`k'.holder_leverage)
    replace hl_cnt = hl_cnt + 1                    if !missing(L`k'.holder_leverage)
}
gen holder_leverage_pre = hl_sum / hl_cnt if hl_cnt > 0
drop hl_sum hl_cnt

gen present = (hf_intensity_pre > 0)

* hl: holder_leverage, set to 0 for no-HF bonds so they remain the zero-intensity
* baseline (their log_hf_intensity is 0, so every interaction term is 0 anyway).
gen hl = holder_leverage_pre
replace hl = 0 if present == 0

* Median of holder_leverage among HF-held bonds (fixed once, reused below)
sum holder_leverage_pre if present, detail
scalar hl_med = r(p50)

* Categorical: 0 = no HF, 1 = low-leverage held, 2 = high-leverage held
gen hf_lev3 = 0
replace hf_lev3 = 1 if present & holder_leverage_pre <= hl_med & !missing(holder_leverage_pre)
replace hf_lev3 = 2 if present & holder_leverage_pre >  hl_med & !missing(holder_leverage_pre)
replace hf_lev3 = . if present & missing(holder_leverage_pre)
label define hf_lev3_lbl 0 "No HF" 1 "Low-leverage" 2 "High-leverage"
label values hf_lev3 hf_lev3_lbl

* Quartiles of holder_leverage among HF-held bonds, vs the no-HF baseline (= 0)
xtile hl_q = holder_leverage_pre if present & !missing(holder_leverage_pre), nq(4)
gen hf_levq = 0
replace hf_levq = hl_q if present & !missing(hl_q)
replace hf_levq = . if present & missing(holder_leverage_pre)
label define hf_levq_lbl 0 "No HF" 1 "Q1 low-lev" 2 "Q2" 3 "Q3" 4 "Q4 high-lev"
label values hf_levq hf_levq_lbl


*===============================================================================
* 3. DESCRIPTIVES (does the measure make sense?)
*===============================================================================
di _n "==== holder_leverage (active bond-days) ===="
count if !missing(holder_leverage)
sum holder_leverage if !missing(holder_leverage), detail
tabstat holder_leverage if !missing(holder_leverage), by(collateral_country) stat(mean p50 sd n)

* Within-cell variation: confirms identification is within day (across bonds in a cell)
bysort duration_match: egen hl_sd_cell = sd(holder_leverage)
sum hl_sd_cell if !missing(hl_sd_cell), detail

* Composition of the low- vs high-leverage groups, country and time mix
* (checks the split is not merely a country or regime proxy).
gen year = year(date_num)
di _n "Country mix of low-leverage (1) vs high-leverage (2):"
tab hf_lev3 collateral_country if inlist(hf_lev3, 1, 2), row
di _n "Period mix by year (column shares within each group):"
tab year hf_lev3 if inlist(hf_lev3, 1, 2), col
drop year

* Aggregate time series of the measure (positioning-weighted).
gen gross_w = gross_long + gross_short
preserve
    keep if !missing(holder_leverage) & gross_w > 0
    collapse (mean) holder_leverage_agg = holder_leverage [aw=gross_w], by(date_num)
    twoway (line holder_leverage_agg date_num, lwidth(medthick) color(navy)), ///
        ytitle("Aggregate holder leverage") xtitle("") ///
        graphregion(color(white)) name(g_ts, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/holder_lev_timeseries.png", replace width(2000)
restore


*===============================================================================
* 4. SPECIFICATIONS
*===============================================================================

* (1) Continuous: hl enters ONLY through HF intensity (no free hl or hl#shock).
* Object of interest: log_hf_intensity # ois_2y # hl  (expect POSITIVE, leverage amplifies).
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hl c.log_hf_intensity#c.ois_2y#c.hl ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (2) Categorical: no-HF baseline vs low-leverage held vs high-leverage held.
* Expect 2.hf_lev3#ois_2y > 1.hf_lev3#ois_2y (high leverage amplifies more).
reghdfe delta_y i.hf_lev3##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_lev3#c.ois_2y = 2.hf_lev3#c.ois_2y

* (3) Quartiles of holder_leverage vs no-HF baseline (dose-response).
* Expect 4.hf_levq#ois_2y > 1.hf_levq#ois_2y.
reghdfe delta_y i.hf_levq##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_levq#c.ois_2y = 4.hf_levq#c.ois_2y


capture log close
