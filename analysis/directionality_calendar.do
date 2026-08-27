********************************************************************************
* DIRECTIONALITY VS CALENDAR TIME - CONSOLIDATED  (discussant slide 20)
* One file for the complete exercise. Produces:
*   Exhibit 1: fund-level directionality and coordination by year
*   Exhibit 2: same-date regressions with HF x date FE
*       (i)   unconditional directional-vs-hedged contrast (expected ~0)
*       (ii)  contrast x sector exposure, nesting triple (expected positive)
*       (iii) intensity x shock (main channel, identified within date)
*   Exhibit 3: announcement-level table, two columns
*       (1) amplification slope vs sector directionality
*       (2) horse race against a 2022 indicator
* Inputs:
*   Data\monetary_policy_induced_position.csv
*   Data\fund_day_directionality.csv  (exported by build\build_main_panel.ipynb)
*   Data\daily_differential.dta       (built by announcement_evidence.do)
* BINW: duration bin width for the duration-country-date cell FE.
********************************************************************************

clear all
local BINW = 2

*=========================== PANEL PREPARATION =================================

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

gen duration_bin   = floor(duration / `BINW') * `BINW'
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* Predetermined holder directionality (5-day trailing mean over prior
* active days, as in directionality.do)
gen hd_sum = 0
gen hd_cnt = 0
forvalues k = 1/5 {
    replace hd_sum = hd_sum + L`k'.holder_dir if !missing(L`k'.holder_dir)
    replace hd_cnt = hd_cnt + 1              if !missing(L`k'.holder_dir)
}
gen holder_dir_pre = hd_sum / hd_cnt if hd_cnt > 0
drop hd_sum hd_cnt

gen present = (hf_intensity_pre > 0)
quietly sum holder_dir_pre if present, detail
scalar hd_med = r(p50)
gen dir_pooled = (present & holder_dir_pre > hd_med & !missing(holder_dir_pre))
drop if present & missing(holder_dir_pre)

* HF-presence x date FE: absorb each date's HF-vs-non-HF level and, since
* the shock is constant within a date, its shock response
egen hf_date = group(present business_date)

* Aggregate (position-weighted) directionality per date
gen gross_w = gross_long + gross_short
preserve
    keep if present & !missing(holder_dir_pre) & gross_w > 0
    collapse (mean) agg_dir = holder_dir_pre [aw = gross_w], by(business_date)
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\agg_dir.dta", replace
restore

merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\agg_dir.dta", ///
    keep(match master) nogenerate
quietly summarize agg_dir
gen agg_dir_c = agg_dir - r(mean)

*=========================== EXHIBIT 2: SAME-DATE REGRESSIONS ==================

* (i) Unconditional directional-vs-hedged contrast among HF bonds, same date
reghdfe delta_y c.dir_pooled##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

* (ii) Contrast x sector exposure (nesting triple)
reghdfe delta_y c.dir_pooled##c.ois_2y##c.agg_dir_c bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

* (iii) Intensity x shock, identified within date
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

*=========================== EXHIBIT 1: FUND-LEVEL TABLE =======================

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\fund_day_directionality.csv", clear

gen date_num = date(business_date, "YMD")
gen year = year(date_num)
keep if gross_dv01 > 0 & !missing(fund_dir)

* Directionality across fund-days: equal-weighted, gross-weighted, shares
di as text _n "==== fund_dir by year: equal-weighted mean, median ===="
tabstat fund_dir, by(year) stat(mean p50 n)
di as text _n "==== fund_dir by year: gross-DV01-weighted mean ===="
preserve
    collapse (mean) fund_dir_gw = fund_dir [aw = gross_dv01], by(year)
    list, noobs
restore
gen dir_50 = (fund_dir > 0.5)
gen dir_80 = (fund_dir > 0.8)
di as text _n "==== shares of fund-days with fund_dir > 0.5 / > 0.8 ===="
tabstat dir_50 dir_80, by(year) stat(mean)

* Direction of the crowd and coordination
gen net_short = (net_dv01 < 0)
di as text _n "==== share net short duration among one-sided fund-days ===="
tabstat net_short if dir_50, by(year) stat(mean n)
di as text _n "==== coordination C by year ===="
preserve
    gen abs_net = abs(net_dv01)
    collapse (sum) sum_net = net_dv01 (sum) sum_absnet = abs_net, ///
        by(business_date year)
    gen coord = abs(sum_net) / sum_absnet if sum_absnet > 0
    tabstat coord, by(year) stat(mean p50)
restore

*=========================== EXHIBIT 3: ANNOUNCEMENT-LEVEL TABLE ===============

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", clear
merge 1:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\agg_dir.dta", ///
    keep(match master) nogenerate
keep if is_ann

quietly summarize agg_dir
gen agg_dir_c = agg_dir - r(mean)
gen s_x_dir  = ois_2y * agg_dir_c
gen s_x_2022 = ois_2y * (year == 2022)

* (1) Regime regression: amplification slope vs sector directionality
reg D ois_2y s_x_dir agg_dir_c, robust

* (2) Horse race against a 2022 indicator
reg D ois_2y s_x_dir agg_dir_c s_x_2022, robust
