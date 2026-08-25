********************************************************************************
* MAIN RESULTS  —  Hedge fund amplification of yield sensitivity
********************************************************************************
* Input : Data\monetary_policy_induced_position.csv  (built by build\build_main_panel.ipynb)
* Produces: Table IV (cols 1-4), Table V, Table VII, Table VIII (console output)

********************************************************************************
* TABLE IV (cols 1-4) — Baseline amplification (binary HF)  +  TABLE V — by shock component (Jarocinski-Karadi)
********************************************************************************


* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

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

********************************************************************************
* TABLE VII — Hedge fund intensity  (and categorical buckets, Appendix Table A4)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

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

********************************************************************************
* TABLE VIII — Intensity by constraint regime (constraining vs relaxing) + pooled Wald test
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

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
