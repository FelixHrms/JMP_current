********************************************************************************
* HOLDER-WEIGHTED HF MARKET POWER AND YIELD AMPLIFICATION
* holder_power is the holdings-weighted market power of a bond's HF holders over
* their dealers (headline = dealer dependence, the fund's share of its dealers'
* HF books). It varies across bonds within a day, so the tests are identified
* within day, free of the cycle, exactly like holder_dir.
* HYPOTHESIS: holders a dealer depends on get margin called less in stress, so
* they fire-sell less and AMPLIFY LESS. Expected signs are therefore the MIRROR
* of the directionality exercise. The triple interaction is NEGATIVE and the
* strong-power group amplifies LESS than the weak-power group.
* Baseline throughout is bonds with no HF activity.
* Swap holder_power -> holder_power_opt for the size-neutral outside-option measure.
********************************************************************************
clear all
set more off

capture log close
log using "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\power_analysis.log", replace text

*===============================================================================
* 1. IMPORT
*===============================================================================
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position_power.csv", clear

drop if business_date >= "2025-10-01"
replace holder_power = holder_power_opt

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
* Predetermine holder_power: 5-day trailing mean over the prior ACTIVE days only
* (idle days are missing and skipped, so they do not pull the average).
gen hp_sum = 0
gen hp_cnt = 0
forvalues k = 1/5 {
    replace hp_sum = hp_sum + L`k'.holder_power if !missing(L`k'.holder_power)
    replace hp_cnt = hp_cnt + 1                 if !missing(L`k'.holder_power)
}
gen holder_power_pre = hp_sum / hp_cnt if hp_cnt > 0
drop hp_sum hp_cnt

gen present = (hf_intensity_pre > 0)

* hp: holder_power, set to 0 for no-HF bonds so they remain the zero-intensity
* baseline (their log_hf_intensity is 0, so every interaction term is 0 anyway).
gen hp = holder_power_pre
replace hp = 0 if present == 0

* Median of holder_power among HF-held bonds (fixed once, reused below)
sum holder_power_pre if present, detail
scalar hp_med = r(p50)

* Categorical: 0 = no HF, 1 = weak-power held, 2 = strong-power held
gen hf_pow3 = 0
replace hf_pow3 = 1 if present & holder_power_pre <= hp_med & !missing(holder_power_pre)
replace hf_pow3 = 2 if present & holder_power_pre >  hp_med & !missing(holder_power_pre)
replace hf_pow3 = . if present & missing(holder_power_pre)
label define hf_pow3_lbl 0 "No HF" 1 "Weak-power" 2 "Strong-power"
label values hf_pow3 hf_pow3_lbl

* Quartiles of holder_power among HF-held bonds, vs the no-HF baseline (= 0)
xtile hp_q = holder_power_pre if present & !missing(holder_power_pre), nq(4)
gen hf_powq = 0
replace hf_powq = hp_q if present & !missing(hp_q)
replace hf_powq = . if present & missing(holder_power_pre)
label define hf_powq_lbl 0 "No HF" 1 "Q1 weak" 2 "Q2" 3 "Q3" 4 "Q4 strong"
label values hf_powq hf_powq_lbl

* Binary regime tag for the local projections (weak vs strong power held)
gen hp_high = .
replace hp_high = 0 if present & holder_power_pre <= hp_med & !missing(holder_power_pre)
replace hp_high = 1 if present & holder_power_pre >  hp_med & !missing(holder_power_pre)


*===============================================================================
* 3. DESCRIPTIVES (does the measure make sense?)
*===============================================================================
di _n "==== holder_power (active bond-days) ===="
count if !missing(holder_power)
sum holder_power if !missing(holder_power), detail
tabstat holder_power if !missing(holder_power), by(collateral_country) stat(mean p50 sd n)

* Within-cell variation: confirms identification is within day (across bonds in a cell)
bysort duration_match: egen hp_sd_cell = sd(holder_power)
sum hp_sd_cell if !missing(hp_sd_cell), detail

* Composition of the weak vs strong groups, country and time mix.
gen year = year(date_num)
di _n "Country mix of weak-power (1) vs strong-power (2):"
tab hf_pow3 collateral_country if inlist(hf_pow3, 1, 2), row
di _n "Period mix by year (column shares within each group):"
tab year hf_pow3 if inlist(hf_pow3, 1, 2), col
drop year

* Aggregate time series of the measure (positioning-weighted).
gen gross_w = gross_long + gross_short
preserve
    keep if !missing(holder_power) & gross_w > 0
    collapse (mean) holder_power_agg = holder_power [aw=gross_w], by(date_num)
    twoway (line holder_power_agg date_num, lwidth(medthick) color(navy)), ///
        ytitle("Aggregate holder market power") xtitle("") ///
        graphregion(color(white)) name(g_ts, replace)
    graph export "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\holder_power_timeseries.png", replace width(2000)
restore


*===============================================================================
* 4. SPECIFICATIONS (your three)
*===============================================================================

* (1) Continuous: hp enters ONLY through HF intensity (no free hp or hp#shock).
* Object of interest: log_hf_intensity # ois_2y # hp  (expect NEGATIVE, power dampens).
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hp c.log_hf_intensity#c.ois_2y#c.hp ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (2) Categorical: no-HF baseline vs weak-power held vs strong-power held.
* Expect 2.hf_pow3#ois_2y < 1.hf_pow3#ois_2y (strong amplifies less).
reghdfe delta_y i.hf_pow3##c.ois_2y bid_ask_spread ctd_flag c.hf_intensity_pre#c.ois_2y, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_pow3#c.ois_2y = 2.hf_pow3#c.ois_2y

* (3) Quartiles of holder_power vs no-HF baseline (dose-response).
* Expect 4.hf_powq#ois_2y < 1.hf_powq#ois_2y.
reghdfe delta_y i.hf_powq##c.ois_2y bid_ask_spread ctd_flag c.hf_intensity_pre#c.ois_2y, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_powq#c.ois_2y = 4.hf_powq#c.ois_2y


*===============================================================================
* 5. POSITION-ADJUSTMENT LOCAL PROJECTIONS BY POWER GROUP (OVERNIGHT)
* Mirrors Section 4.1 of empirics_v1.do (the published position IRF), run on the
* OVERNIGHT panel and split into weak- vs strong-power holders. Overnight repo is
* the only segment that can re-price daily, so this is where the adjustment shows;
* the all-repo panel is dominated by locked term positions and looks unresponsive.
* For each power group it plots the cumulative HF intensity response to a
* constraining and a relaxing shock. Pinned (weak) funds should ride the cycle in
* both regimes; slack (strong) funds should be flatter.
*===============================================================================
clear all
set more off

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position_overnight_power.csv", clear

drop if business_date >= "2025-10-01"

* size-purged power measure (higher = more power); swap as in Section 1 if desired
replace holder_power = holder_power_opt

gen date_num = date(business_date, "YMD")
format date_num %td
egen isin_id = group(isin)

* one observation per bond-day; carry the shock, position side, and power through
collapse (sum) delta_intensity ///
         (firstnm) is_long_pre is_short_pre ois_2y collateral_country holder_power ///
         (mean) duration bid_ask_spread ctd_flag, ///
         by(isin_id date_num)

gen duration_bin = floor(duration / 2) * 2
gen business_date_str = string(date_num, "%tdCCYY-NN-DD")
gen duration_match = string(duration_bin) + "_" + business_date_str + "_" + collateral_country

sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

local controls "bid_ask_spread ctd_flag"

* predetermined power (5-day trailing mean over prior active days) and median split
gen hp_sum = 0
gen hp_cnt = 0
forvalues k = 1/5 {
    replace hp_sum = hp_sum + L`k'.holder_power if !missing(L`k'.holder_power)
    replace hp_cnt = hp_cnt + 1                 if !missing(L`k'.holder_power)
}
gen holder_power_pre = hp_sum / hp_cnt if hp_cnt > 0
drop hp_sum hp_cnt
sum holder_power_pre if !missing(holder_power_pre), detail
scalar hp_med = r(p50)
gen hp_high = .
replace hp_high = 0 if holder_power_pre <= hp_med & !missing(holder_power_pre)
replace hp_high = 1 if holder_power_pre >  hp_med & !missing(holder_power_pre)

* regime-oriented shocks, exactly as in empirics_v1.do Section 4.1
gen cons_shock = ois_2y * is_long_pre  if ois_2y > 0
replace cons_shock = ois_2y * is_short_pre if ois_2y < 0
replace cons_shock = 0 if missing(cons_shock)
gen relax_shock = ois_2y * is_short_pre if ois_2y > 0
replace relax_shock = ois_2y * is_long_pre if ois_2y < 0
replace relax_shock = 0 if missing(relax_shock)

* IRF loop, run separately for weak (0) and strong (1) power holders
tempname memhold
tempfile irf_results
postfile `memhold' grp horizon b_cons se_cons b_relax se_relax using `irf_results', replace
quietly forvalues g = 0/1 {
    forvalues h = 0/10 {
        xtset isin_id bday_time
        cap drop cumulative_flow
        gen cumulative_flow = 0
        forval i = 0/`h' {
            replace cumulative_flow = cumulative_flow + F`i'.delta_intensity
        }
        reghdfe cumulative_flow cons_shock relax_shock `controls' if hp_high==`g', ///
            absorb(duration_match isin_id) vce(cluster isin_id)
        post `memhold' (`g') (`h') (_b[cons_shock]) (_se[cons_shock]) ///
                       (_b[relax_shock]) (_se[relax_shock])
    }
}
postclose `memhold'

* PLOTTING: weak vs strong within each regime
use `irf_results', clear
foreach r in cons relax {
    gen hi_`r' = b_`r' + 1.64*se_`r'
    gen lo_`r' = b_`r' - 1.64*se_`r'
}
local base_opts "yline(0, lcolor(black) lpattern(dash)) xlabel(0(1)10) graphregion(color(white))"

twoway (rarea hi_cons lo_cons horizon if grp==0, color(cranberry%20) lwidth(none)) ///
       (rarea hi_cons lo_cons horizon if grp==1, color(navy%20) lwidth(none)) ///
       (line b_cons horizon if grp==0, color(cranberry) lwidth(thick)) ///
       (line b_cons horizon if grp==1, color(navy) lwidth(thick) lpattern(dash)), ///
    title("Constraining", size(medium)) name(g_cons, replace) `base_opts' ///
    ytitle("Cumul. change HF intensity (pp)") xtitle("Days since shock") ///
    legend(order(3 "Weak power" 4 "Strong power") rows(1) position(6) region(lstyle(none)))

twoway (rarea hi_relax lo_relax horizon if grp==0, color(cranberry%20) lwidth(none)) ///
       (rarea hi_relax lo_relax horizon if grp==1, color(navy%20) lwidth(none)) ///
       (line b_relax horizon if grp==0, color(cranberry) lwidth(thick)) ///
       (line b_relax horizon if grp==1, color(navy) lwidth(thick) lpattern(dash)), ///
    title("Relaxing", size(medium)) name(g_relax, replace) `base_opts' ///
    ytitle("") xtitle("Days since shock") ///
    legend(order(3 "Weak power" 4 "Strong power") rows(1) position(6) region(lstyle(none)))

graph combine g_cons g_relax, rows(1) graphregion(color(white)) name(g_pos_power, replace)
graph export "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\IR_position_power.png", replace width(2400)


capture log close
