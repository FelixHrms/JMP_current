********************************************************************************
* FUND-LEVEL DIRECTIONALITY AND COORDINATION, BY YEAR
* Substantiates the regime claim ("in 2022 the sector ran one-sided books,
* by 2025 hedged books") at the level where it is defined: the fund.
* Separates two configurations the bond-level aggregate cannot distinguish:
*   (i)  funds one-sided in the SAME direction (crowded trade: one shock
*        hits every book at once), vs
*   (ii) funds one-sided in OFFSETTING directions.
*
* Requires: Data\fund_day_directionality.csv. To create it, paste the cell
* below at the END of build\build_main_panel.ipynb (after the holder_dir
* section, where the fund-bond-day frame `fb` with dv01/absdv01 exists)
* and run it:
*
*   # Export fund-day directionality panel for the appendix descriptives
*   fund_day = fb.groupby(['business_date','fund_id']).agg(
*       net_dv01=('dv01','sum'),
*       gross_dv01=('absdv01','sum'),
*   ).reset_index()
*   fund_day['fund_dir'] = fund_day['net_dv01'].abs() / \
*       fund_day['gross_dv01'].where(fund_day['gross_dv01'] > 0)
*   fund_day.to_csv(r'C:\Users\hermesf\Projects\JobMarket\Data\fund_day_directionality.csv',
*                   index=False)
*
* Sign convention: net_dv01 < 0 = net short duration (gains when yields
* rise). All output is aggregated across 100+ funds per year.
********************************************************************************

clear all

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\fund_day_directionality.csv", clear

gen date_num = date(business_date, "YMD")
format date_num %td
gen year = year(date_num)

keep if gross_dv01 > 0 & !missing(fund_dir)

********************************************************************************
* 1. Fund-level directionality by year
*    "Everyone one-sided in 2022, everyone hedged in 2025" in numbers.
********************************************************************************

* Activity: fund-days and distinct funds per year
bysort year fund_id: gen first_fy = (_n == 1)
di as text _n "==== active fund-days and distinct funds per year ===="
tab year
tab year if first_fy

* Distribution of fund_dir across fund-days, by year (equal-weighted)
di as text _n "==== fund_dir by year, equal-weighted across fund-days ===="
tabstat fund_dir, by(year) stat(mean p25 p50 p75 sd n)

* Gross-weighted mean (big books count more)
di as text _n "==== fund_dir by year, gross-DV01-weighted ===="
preserve
    collapse (mean) fund_dir_gw = fund_dir [aw = gross_dv01], by(year)
    list, noobs
restore

* Share of fund-days with one-sided books
gen dir_50 = (fund_dir > 0.5)
gen dir_80 = (fund_dir > 0.8)
di as text _n "==== share of fund-days with fund_dir > 0.5 and > 0.8 ===="
tabstat dir_50 dir_80, by(year) stat(mean n)

********************************************************************************
* 2. Coordination by year
*    C_t = |sum of fund net DV01s| / sum of |fund net DV01s| across funds,
*    per date. C_t = 1: every directional book points the same way (crowded).
*    C_t = 0: directional books fully offset each other.
********************************************************************************

preserve
    gen abs_net = abs(net_dv01)
    collapse (sum) sum_net = net_dv01 (sum) sum_absnet = abs_net, by(business_date year)
    gen coord = abs(sum_net) / sum_absnet if sum_absnet > 0
    di as text _n "==== coordination C_t by year (mean, median across days) ===="
    tabstat coord, by(year) stat(mean p50 sd n)
restore

* Which way do the one-sided books point? Share of directional fund-days
* (fund_dir > 0.5) that are net short duration, by year.
gen net_short = (net_dv01 < 0)
di as text _n "==== share net short duration among fund-days with fund_dir > 0.5 ===="
tabstat net_short if dir_50, by(year) stat(mean n)
