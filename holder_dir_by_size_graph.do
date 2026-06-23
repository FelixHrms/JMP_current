********************************************************************************
* HOLDER DIRECTIONALITY BY FUND SIZE: TIME SERIES (GRAPH ONLY)
* Two aggregate directionality series over time: the 10 largest hedge funds
* (ranked by total gross repo book over the sample) vs all other hedge funds.
* Each series is the position-weighted (gross book) mean of fund-level DV01
* directionality (fund_dir in [0,1]; 0 = hedged carry / relative value,
* 1 = directional). This lets us read off both the LEVEL difference and the
* TIME-SERIES patterns of large vs small funds.
*
* This file ONLY produces the graph. The input fund_dir_by_size.csv is a
* fund-day panel (business_date, fund_id, gross, fund_dir, top10) written by
* empirics_v1_temp.ipynb.
********************************************************************************
clear all
set more off

*===============================================================================
* 1. IMPORT
*===============================================================================
import delimited "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Data/fund_dir_by_size.csv", clear

gen date_num = date(business_date, "YMD")
format date_num %td
drop if missing(fund_dir)

*===============================================================================
* 2. AGGREGATE TO DATE x GROUP (position-weighted) AND PLOT
*===============================================================================
collapse (mean) fund_dir_agg = fund_dir [aw=gross], by(date_num top10)

twoway (line fund_dir_agg date_num if top10==1, lwidth(medthick) color(navy)) ///
       (line fund_dir_agg date_num if top10==0, lwidth(medthick) color(cranberry)), ///
    ytitle("Aggregate holder directionality") xtitle("") ///
    yline(0.5, lcolor(gs10) lpattern(dash)) ///
    legend(order(1 "Top 10 funds" 2 "All other funds") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) name(g_dir_size, replace)

graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/holder_dir_by_size_timeseries.png", replace width(2000)
