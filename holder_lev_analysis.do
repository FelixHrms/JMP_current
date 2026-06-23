********************************************************************************
* HOLDER-WEIGHTED HF LEVERAGE AND YIELD AMPLIFICATION + SPECIALNESS HORSE RACE
* holder_leverage is the holdings-weighted leverage of a bond's HF holders, built
* as -(|net|-weighted mean |repo haircut|): higher = more leveraged. Exactly-0
* haircuts are dropped upstream (cross-margined / unreported, not zero-margin).
*
* The repo haircut is mechanically tied to two collateral/contract characteristics:
*   holder_special  = ESTR - specific repo rate (pp, higher = more special)
*   holder_maturity = repo contractual maturity (days)
* The HORSE RACE asks whether the leverage interaction survives once these are held
* fixed. Two readings, both useful:
*   - leverage triple SURVIVES  -> haircut carries leverage info beyond specialness
*                                  and term (mechanism-consistent if it turns positive).
*   - leverage triple VANISHES  -> the haircut result was specialness / funding term;
*                                  haircuts conflate counterparty and collateral risk,
*                                  so the haircut alone is not enough and the two must
*                                  be decomposed.
* All measures enter ONLY through HF intensity, identified within day, free of the
* cycle, against a baseline of bonds with no HF activity.
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
* 2. CREATE THE MEASURES
*===============================================================================
* Predetermine each holder-weighted measure: 5-day trailing mean over the prior
* ACTIVE days only (idle days are missing and skipped, so they do not pull the mean).
foreach v in holder_leverage holder_special holder_maturity {
    capture confirm variable `v'
    if _rc {
        di as error "`v' not found -- re-run empirics_v1.ipynb to regenerate the CSV"
        exit 111
    }
    gen `v'_sum = 0
    gen `v'_cnt = 0
    forvalues k = 1/5 {
        replace `v'_sum = `v'_sum + L`k'.`v' if !missing(L`k'.`v')
        replace `v'_cnt = `v'_cnt + 1        if !missing(L`k'.`v')
    }
    gen `v'_pre = `v'_sum / `v'_cnt if `v'_cnt > 0
    drop `v'_sum `v'_cnt
}

gen present = (hf_intensity_pre > 0)

* Continuous regressors set to 0 for no-HF bonds (their log_hf_intensity is 0, so
* every interaction is 0 anyway); they stay missing for HF bonds lacking the measure.
gen hl   = holder_leverage_pre
gen hsp  = holder_special_pre
gen hmat = holder_maturity_pre
replace hl   = 0 if present == 0
replace hsp  = 0 if present == 0
replace hmat = 0 if present == 0

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
* 3. DESCRIPTIVES (do the measures make sense?)
*===============================================================================
di _n "==== holder_leverage (active bond-days) ===="
count if !missing(holder_leverage)
sum holder_leverage if !missing(holder_leverage), detail
tabstat holder_leverage if !missing(holder_leverage), by(collateral_country) stat(mean p50 sd n)

di _n "==== specialness & maturity (active bond-days) ===="
sum holder_special holder_maturity if present, detail

* Collinearity of the three predetermined measures: tells us whether the horse race
* can actually separate leverage from specialness and term.
di _n "Correlation of the three predetermined holder measures (HF-held bonds):"
pwcorr holder_leverage_pre holder_special_pre holder_maturity_pre if present, sig

* Within-cell variation: confirms identification is within day (across bonds in a cell)
bysort duration_match: egen hl_sd_cell = sd(holder_leverage)
sum hl_sd_cell if !missing(hl_sd_cell), detail

* Aggregate time series of the leverage measure (positioning-weighted).
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

* --- Leverage alone ----------------------------------------------------------

* (1) Continuous: hl enters ONLY through HF intensity (no free hl or hl#shock).
* Object of interest: log_hf_intensity # ois_2y # hl.
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hl c.log_hf_intensity#c.ois_2y#c.hl ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (2) Categorical: no-HF baseline vs low-leverage held vs high-leverage held.
reghdfe delta_y i.hf_lev3##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_lev3#c.ois_2y = 2.hf_lev3#c.ois_2y

* (3) Quartiles of holder_leverage vs no-HF baseline (dose-response).
reghdfe delta_y i.hf_levq##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_levq#c.ois_2y = 4.hf_levq#c.ois_2y

* --- HORSE RACE: leverage vs specialness and repo maturity -------------------
* Object of interest stays log_hf_intensity#ois_2y#hl. Does it survive once the
* collateral/contract drivers of the haircut are held fixed?

* (4a) leverage + specialness
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hl  c.log_hf_intensity#c.ois_2y#c.hl ///
    c.log_hf_intensity#c.hsp c.log_hf_intensity#c.ois_2y#c.hsp ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (4b) leverage + specialness + repo maturity (full horse race)
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hl   c.log_hf_intensity#c.ois_2y#c.hl ///
    c.log_hf_intensity#c.hsp  c.log_hf_intensity#c.ois_2y#c.hsp ///
    c.log_hf_intensity#c.hmat c.log_hf_intensity#c.ois_2y#c.hmat ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)


capture log close
