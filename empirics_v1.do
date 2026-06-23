********MON POL
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)

reghdfe delta_y i.hf_involved##c.mp_pm bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y i.hf_involved##c.cbi_pm bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)

reghdfe delta_y i.hf_involved##c.mp_pm i.hf_involved##c.cbi_pm bid_ask_spread ctd_flag, ///
    absorb(isin duration_match) vce(cluster business_date isin)

test 1.hf_involved#c.mp_pm = 1.hf_involved#c.cbi_pm


* 2.1 persistence

* Group by ISIN and Date to ensure uniqueness
egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
format date_num %td

duplicates drop isin_id date_num, force

replace hf_involved = round(hf_involved)
recast byte hf_involved
* IMPORTANT: Create a sequential business day counter to avoid 'gaps' in xtset
sort isin_id date_num
by isin_id: gen bday_time = _n

* Define the panel
xtset isin_id bday_time

* Define controls for the loop
local controls "bid_ask_spread ctd_flag"


* BASELINE IRF LOOP (YIELD AMPLIFICATION)
tempname memhold
tempfile baseline_results
postfile `memhold' horizon beta se using `baseline_results', replace
quietly forvalues h = -5/10 {
    
    cap drop cumul_dy
    if `h' >= 0 {
        gen cumul_dy = (F`h'.yld_mid - L1.yld_mid) * 100
    }
    else {
        local lag = abs(`h') + 1
        gen cumul_dy = (L1.yld_mid - L`lag'.yld_mid) * 100
    }
    
    reghdfe cumul_dy i.hf_involved##c.ois_2y `controls', ///
            absorb(isin duration_match) vce(cluster date_num isin_id)
            
    post `memhold' (`h') (_b[1.hf_involved#c.ois_2y]) (_se[1.hf_involved#c.ois_2y])
}
postclose `memhold'

* VISUALIZATION
preserve
    use `baseline_results', clear
    
    gen ci_up = beta + 1.64*se
    gen ci_lo = beta - 1.64*se
    
    twoway (rarea ci_up ci_lo horizon, color(red%20) lwidth(none)) ///
           (line beta horizon, color(cranberry) lwidth(thick)), ///
           yline(0, lcolor(black) lpattern(dash)) ///
           ytitle("Additional Yield Impact (bps)") ///
           xtitle("Days since Shock (Horizon)") ///
           xlabel(-5(1)10) ///
           legend(off) ///
           graphregion(color(white)) 
restore







*2.2 intensity
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
* Recode so that None=0, Low=1, High=2 (ascending intensity)
recode hf_cat (1=0) (3=1) (2=2)
label define hf_cat_lbl 0 "None" 1 "Low" 2 "High"
label values hf_cat hf_cat_lbl


encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

reghdfe delta_y c.hf_intensity_pre##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y c.hf_intensity_pre##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y c.hf_intensity_pre##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y c.hf_intensity_pre##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


gen log_hf_intensity = log(1 + hf_intensity_pre)

reghdfe delta_y c.log_hf_intensity##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


encode hf_category_ext, gen(hf_cat_ex)
recode hf_cat_ex (1=0) (3=1) (4=2) (2=3)
label define hf_cat_ex_lbl 0 "None" 1 "Low" 2 "Medium" 3 "High"
label values hf_cat_ex hf_cat_ex_lbl
tab hf_cat_ex

reghdfe delta_y i.hf_cat_ex##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y i.hf_cat_ex##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y i.hf_cat_ex##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y i.hf_cat_ex##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_cat_ex#c.ois_2y = 3.hf_cat_ex#c.ois_2y



reghdfe delta_y i.hf_cat##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y i.hf_cat##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y i.hf_cat##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y i.hf_cat##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_cat#c.ois_2y = 2.hf_cat#c.ois_2y




* 3. Asymmetries
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
* Recode so that None=0, Low=1, High=2 (ascending intensity)
recode hf_cat (1=0) (3=1) (2=2)
label define hf_cat_lbl 0 "None" 1 "Low" 2 "High"
label values hf_cat hf_cat_lbl

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
	
	
	
* test for equivalence
gen sample_pool = ((ois_2y > 0 & hf_intensity_long > 0) ///
    | (ois_2y < 0 & hf_intensity_short > 0) ///
    | (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
    | (ois_2y == 0) ///
    | (hf_intensity_pre == 0))

gen relaxing = ((ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0))

gen intxshock = log_hf_intensity * ois_2y
gen intxshockxrelax = intxshock * relaxing

reghdfe delta_y log_hf_intensity ois_2y intxshock relaxing intxshockxrelax ///
    bid_ask_spread ctd_flag if sample_pool, ///
    absorb(duration_match isin) vce(cluster business_date isin)
	
	

* categorical
reghdfe delta_y i.hf_cat##c.ois_2y bid_ask_spread ctd_flag if ois_2y >= 0, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y i.hf_cat##c.ois_2y bid_ask_spread ctd_flag if ois_2y <= 0, absorb(duration_match isin) vce(cluster business_date isin)



	
	
	
	
* 4.1 Position Adjustment by Constraint Regime
clear all

* 1. Import and Prepare
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\monetary_policy_induced_position.csv", clear
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
format date_num %td

* Ensure one observation per bond-day
collapse (sum) delta_intensity ///
         (firstnm) is_long_pre is_short_pre ois_2y collateral_country ///
         (mean) duration bid_ask_spread ctd_flag, ///
         by(isin_id date_num)

gen duration_bin = floor(duration / 2) * 2
gen business_date_str = string(date_num, "%tdCCYY-NN-DD")
gen duration_match = string(duration_bin) + "_" + business_date_str + "_" + collateral_country

sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

local controls "bid_ask_spread ctd_flag"

* Construct regime-specific position indicators interacted with shock
* Constraining: long & tightening, or short & easing
gen cons_shock = ois_2y * is_long_pre  if ois_2y > 0
replace cons_shock = ois_2y * is_short_pre if ois_2y < 0
replace cons_shock = 0 if missing(cons_shock)

* Relaxing: short & tightening, or long & easing
gen relax_shock = ois_2y * is_short_pre if ois_2y > 0
replace relax_shock = ois_2y * is_long_pre if ois_2y < 0
replace relax_shock = 0 if missing(relax_shock)

* 2. STORAGE SETUP
tempname memhold
tempfile irf_results
postfile `memhold' horizon b_cons se_cons b_relax se_relax ///
    using `irf_results', replace

* 3. IRF LOOP
quietly forvalues h = 0/10 {
    
    * LHS: Reconstruct cumulative position change from flows
    cap drop cumulative_flow
    gen cumulative_flow = 0
    forval i = 0/`h' {
        replace cumulative_flow = cumulative_flow + F`i'.delta_intensity
    }
    
    * Single regression with both regime interactions
    reghdfe cumulative_flow cons_shock relax_shock `controls', ///
        absorb(duration_match isin_id) vce(cluster isin_id)
    
    local bC = _b[cons_shock]
    local sC = _se[cons_shock]
    local bR = _b[relax_shock]
    local sR = _se[relax_shock]
    
    post `memhold' (`h') (`bC') (`sC') (`bR') (`sR')
}
postclose `memhold'

* 4. PLOTTING
use `irf_results', clear

local my_scale "yscale(range(-0.08 0.08)) ylabel(-0.08(0.02)0.08)"
local base_opts "yline(0, lcolor(black) lpattern(dash)) xlabel(0(1)10) legend(off) graphregion(color(white)) `my_scale'"

* Constraining IRF
gen hi_cons = b_cons + 1.64*se_cons
gen lo_cons = b_cons - 1.64*se_cons

twoway (rarea hi_cons lo_cons horizon, color(gs14) lwidth(none)) ///
       (line b_cons horizon, color(navy) lwidth(thick)), ///
       title("Constraining", size(medium)) name(g_cons, replace) ///
       legend(off) `base_opts' ytitle("Cumul. Change HF Intensity (pp)") xtitle("Days since Shock")

* Relaxing IRF
gen hi_relax = b_relax + 1.64*se_relax
gen lo_relax = b_relax - 1.64*se_relax

twoway (rarea hi_relax lo_relax horizon, color(gs14) lwidth(none)) ///
       (line b_relax horizon, color(maroon) lwidth(thick)), ///
       title("Relaxing", size(medium)) name(g_relax, replace) ///
       legend(off) `base_opts' ytitle("") xtitle("Days since Shock")

graph combine g_cons g_relax, iscale(*0.9) imargin(small) rows(1)



********************************************************************************
**********************FOR LATER*************************************************
********************************************************************************


* 5. Core-periphery
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y##i.col_cntr ///
    c.hf_intensity_short##c.ois_2y##i.col_cntr ///
    bid_ask_spread ctd_flag ///
	if shock >= 0, ///
    absorb(duration_match isin) vce(cluster business_date isin)
	
reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y##i.col_cntr ///
    c.hf_intensity_short##c.ois_2y##i.col_cntr ///
    bid_ask_spread ctd_flag ///
	if ois_2y <= 0, ///
    absorb(duration_match isin) vce(cluster business_date isin)
	

	
	
* 5.1 Persistence 
clear all
set more off

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

* Encode country (Assuming 1=Germany, 2=Italy)
encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date

* DATA PREPARATION

egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
egen time_id = group(date_num)
duplicates drop isin_id time_id, force
xtset isin_id time_id

* Ensure Germany=1, Italy=2 (Check your encode result, adjust if necessary)
* Define the controls exactly as in your provided regression
local controls "bid_ask_spread ctd_flag"


* STORAGE SETUP
tempname memhold
tempfile results
postfile `memhold' horizon ///
    b_TL_DE se_TL_DE b_TS_DE se_TS_DE ///
    b_TL_IT se_TL_IT b_TS_IT se_TS_IT ///
    b_EL_DE se_EL_DE b_ES_DE se_ES_DE ///
    b_EL_IT se_EL_IT b_ES_IT se_ES_IT ///
    using `results', replace

* LOCAL PROJECTIONS LOOP

quietly forvalues h = 0/10 {
    
    * LHS: Cumulative change (bps)
    cap drop temp_lhs
    gen temp_lhs = (F`h'.yld_mid - L1.yld_mid) * 100
    
    * --- REGIME 1: TIGHTENING (shock >= 0) ---
    reghdfe temp_lhs ///
        c.hf_intensity_long##c.ois_2y##i.col_cntr ///
        c.hf_intensity_short##c.ois_2y##i.col_cntr ///
        `controls' if ois_2y >= 0, absorb(duration_match isin_id) vce(cluster time_id isin_id)

    * Germany (Base Effect)
    lincom c.hf_intensity_long#c.ois_2y
    local bTL_DE = r(estimate)
    local sTL_DE = r(se)
    
    lincom c.hf_intensity_short#c.ois_2y
    local bTS_DE = r(estimate)
    local sTS_DE = r(se)

    * Italy (TOTAL EFFECT = Core + Periphery Additional)
    lincom c.hf_intensity_long#c.ois_2y + 2.col_cntr#c.hf_intensity_long#c.ois_2y
    local bTL_IT = r(estimate)
    local sTL_IT = r(se)
    
    lincom c.hf_intensity_short#c.ois_2y + 2.col_cntr#c.hf_intensity_short#c.ois_2y
    local bTS_IT = r(estimate)
    local sTS_IT = r(se)

    * --- REGIME 2: EASING (shock <= 0) ---
    reghdfe temp_lhs ///
        c.hf_intensity_long##c.ois_2y##i.col_cntr ///
        c.hf_intensity_short##c.ois_2y##i.col_cntr ///
        `controls' if ois_2y <= 0, absorb(duration_match isin_id) vce(cluster time_id isin_id)

    * Germany (Base Effect)
    lincom c.hf_intensity_long#c.ois_2y
    local bEL_DE = r(estimate)
    local sEL_DE = r(se)
    
    lincom c.hf_intensity_short#c.ois_2y
    local bES_DE = r(estimate)
    local sES_DE = r(se)

    * Italy (TOTAL EFFECT = Core + Periphery Additional)
    lincom c.hf_intensity_long#c.ois_2y + 2.col_cntr#c.hf_intensity_long#c.ois_2y
    local bEL_IT = r(estimate)
    local sEL_IT = r(se)
    
    lincom c.hf_intensity_short#c.ois_2y + 2.col_cntr#c.hf_intensity_short#c.ois_2y
    local bES_IT = r(estimate)
    local sES_IT = r(se)

    post `memhold' (`h') ///
        (`bTL_DE') (`sTL_DE') (`bTS_DE') (`sTS_DE') ///
        (`bTL_IT') (`sTL_IT') (`bTS_IT') (`sTS_IT') ///
        (`bEL_DE') (`sEL_DE') (`bES_DE') (`sES_DE') ///
        (`bEL_IT') (`sEL_IT') (`bES_IT') (`sES_IT')
}
postclose `memhold'


* PLOTTING

use `results', clear

* Shared base options
local base_opts "yline(0, lcolor(black) lpattern(dash)) xlabel(0(1)10) legend(off) graphregion(color(white)) ylabel(-0.1(0.05)0.1, grid)"

foreach shock in T E {
    local s_name = cond("`shock'"=="T", "Tightening", "Easing")
    
    * Plot 1: DE Long (Top Left) -> Y-axis label ON, X-axis label OFF
    gen hi_`shock'L_DE = b_`shock'L_DE + 1.64*se_`shock'L_DE
    gen lo_`shock'L_DE = b_`shock'L_DE - 1.64*se_`shock'L_DE
    replace hi_`shock'L_DE = min(hi_`shock'L_DE, 0.1)
    replace lo_`shock'L_DE = max(lo_`shock'L_DE, -0.1)
    twoway (rarea hi_`shock'L_DE lo_`shock'L_DE horizon, color(gs14) lwidth(none)) ///
           (line b_`shock'L_DE horizon, color(navy) lwidth(thick)), ///
           title("Core Long", size(medium)) name(g_`shock'L_DE, replace) `base_opts' ///
           ytitle("Amplification in bps") xtitle("")

    * Plot 2: DE Short (Top Right) -> Y-axis label OFF, X-axis label OFF
    gen hi_`shock'S_DE = b_`shock'S_DE + 1.64*se_`shock'S_DE
    gen lo_`shock'S_DE = b_`shock'S_DE - 1.64*se_`shock'S_DE
    replace hi_`shock'S_DE = min(hi_`shock'S_DE, 0.1)
    replace lo_`shock'S_DE = max(lo_`shock'S_DE, -0.1)
    twoway (rarea hi_`shock'S_DE lo_`shock'S_DE horizon, color(gs14) lwidth(none)) ///
           (line b_`shock'S_DE horizon, color(navy) lwidth(thick)), ///
           title("Core Short", size(medium)) name(g_`shock'S_DE, replace) `base_opts' ///
           ytitle("") xtitle("")

    * Plot 3: IT Long (Bottom Left) -> Y-axis label ON, X-axis label ON
    gen hi_`shock'L_IT = b_`shock'L_IT + 1.64*se_`shock'L_IT
    gen lo_`shock'L_IT = b_`shock'L_IT - 1.64*se_`shock'L_IT
    replace hi_`shock'L_IT = min(hi_`shock'L_IT, 0.1)
    replace lo_`shock'L_IT = max(lo_`shock'L_IT, -0.1)
    twoway (rarea hi_`shock'L_IT lo_`shock'L_IT horizon, color(gs14) lwidth(none)) ///
           (line b_`shock'L_IT horizon, color(navy) lwidth(thick)), ///
           title("Periphery Long", size(medium)) name(g_`shock'L_IT, replace) `base_opts' ///
           ytitle("Amplification in bps") xtitle("Days since Shock")

    * Plot 4: IT Short (Bottom Right) -> Y-axis label OFF, X-axis label ON
    gen hi_`shock'S_IT = b_`shock'S_IT + 1.64*se_`shock'S_IT
    gen lo_`shock'S_IT = b_`shock'S_IT - 1.64*se_`shock'S_IT
    replace hi_`shock'S_IT = min(hi_`shock'S_IT, 0.1)
    replace lo_`shock'S_IT = max(lo_`shock'S_IT, -0.1)
    twoway (rarea hi_`shock'S_IT lo_`shock'S_IT horizon, color(gs14) lwidth(none)) ///
           (line b_`shock'S_IT horizon, color(navy) lwidth(thick)), ///
           title("Periphery Short", size(medium)) name(g_`shock'S_IT, replace) `base_opts' ///
           ytitle("") xtitle("Days since Shock")

    * Combine them
    graph combine g_`shock'L_DE g_`shock'S_DE g_`shock'L_IT g_`shock'S_IT, ///
        name(Fig_`shock', replace)
}

graph display Fig_T
graph display Fig_E


* 5.2 Germany as a hedge
*==============================================================================
* 1. DATA IMPORT & PREPARATION
*==============================================================================
clear all
set more off

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

* Convert business_date to a numeric Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* Encode countries
encode collateral_country, gen(col_cntr)

*==============================================================================
* 1. PREPARE DATA
*==============================================================================
keep date_num col_cntr hf_intensity_long hf_intensity_short

gen c_name = ""
replace c_name = "DE" if col_cntr == 1
replace c_name = "IT" if col_cntr == 2
keep if c_name != ""

collapse (mean) hf_intensity_long hf_intensity_short, by(date_num c_name)
reshape wide hf_intensity_long hf_intensity_short, i(date_num) j(c_name) string
tsset date_num

* Create differences (Changes)
foreach v of varlist hf_intensity* {
    gen d_`v' = `v' - L.`v'
}

*==============================================================================
* 2. REFINED UNIQUENESS TESTS
*==============================================================================
est clear

reg d_hf_intensity_shortDE d_hf_intensity_longIT, robust
reg d_hf_intensity_shortDE d_hf_intensity_shortIT, robust
reg d_hf_intensity_shortDE d_hf_intensity_longDE, robust


* Column 5: The Sanity Check (Reciprocal)
reg d_hf_intensity_longDE d_hf_intensity_shortIT, robust
reg d_hf_intensity_longDE d_hf_intensity_longIT, robust
















