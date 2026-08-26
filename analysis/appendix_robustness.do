********************************************************************************
* APPENDIX ROBUSTNESS  —  monetary-policy specifications
********************************************************************************
* Input : Data\monetary_policy_induced_position.csv  and  ..._country.csv
* Produces: Appendix Tables A1 (expanded sample), A2 (placebo), A3 (orthogonality), A6 (excl. CTD)

********************************************************************************
* APPENDIX TABLE A2 — Placebo (shock dates shifted 15 trading days)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.placebo_shock duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag ///
    if (placebo_shock > 0 & hf_intensity_long > 0) ///
 | (placebo_shock < 0 & hf_intensity_short > 0) ///
 | (placebo_shock == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag ///
    if (placebo_shock > 0 & hf_intensity_short > 0) ///
    | (placebo_shock < 0 & hf_intensity_long > 0) ///
	| (placebo_shock == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* APPENDIX TABLE A6 — Excluding CTD bonds
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

keep if ctd_flag == 0

gen log_hf_intensity = log(1 + hf_intensity_pre)


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* APPENDIX TABLE A1 — Expanded sovereign sample (DE, IT, FR, ES)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position_country.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

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

********************************************************************************
* APPENDIX TABLE A3 — Orthogonality of HF positioning to the MP surprise
********************************************************************************

* Orthogonality of positions
* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) ois_2y (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to ECB meeting days and test orthogonality
keep if ois_2y != 0
reg ois_2y lag_net_pos, robust

********************************************************************************
* APPENDIX TABLES A8-A10 — Positioning measured from classified fund types only
********************************************************************************
* Inputs: Data\monetary_policy_induced_position_fimacro.csv  (FI/rates-RV + macro)
*         Data\monetary_policy_induced_position_fi.csv       (FI/rates-RV only)
*         Data\monetary_policy_induced_position_macro.csv    (global macro only)
*         (built by build\build_strategy_panel.ipynb; hf_involved_all /
*         hf_intensity_all carry the baseline all-fund flags; bond-side
*         variables identical to the baseline panel)
* Bond-days positioned ONLY by hedge funds outside the respective set are
* excluded, so the control group is bonds with no hedge fund at all. Keeping
* them as controls instead (drop the exclusion) is the conservative variant:
* it can only attenuate the interaction.
* Directionality prediction: macro books are directional, FI/RV books hedged,
* so the macro-only interaction should exceed the FI-only one (cf. Table IX).

foreach seg in fimacro fi macro {

    di as text _n "================ positioning set: `seg' ================"

    clear
    import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position_`seg'.csv", clear

    encode collateral_country, gen(col_cntr)
    gen duration_bin = floor(duration / 2) * 2
    gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

    gen log_hf_intensity = log(1 + hf_intensity_pre)

    * exclude bond-days held only by hedge funds outside this set
    drop if hf_involved == 0 & hf_involved_all == 1

    * Baseline regression
    reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
    reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

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
}

********************************************************************************
* APPENDIX TABLE A11 — FI vs macro positioning jointly, same bonds, same cells
********************************************************************************
* Input : Data\monetary_policy_induced_position_fimacro.csv (carries per-type
*         intensities hf_intensity_fi / hf_intensity_macro)
* Both interactions enter one regression, so each type's amplification is
* identified holding the other type's position in the same bond constant.
* This addresses (i) macro and FI funds co-locating in the same bonds and
* (ii) the size difference (macro positions are much smaller): the raw-pp
* variant compares amplification per percentage point of outstanding held.

clear all
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position_fimacro.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_int_fi    = log(1 + hf_intensity_fi)
gen log_int_macro = log(1 + hf_intensity_macro)

* exclude bond-days held only by hedge funds outside FI/macro
drop if hf_involved == 0 & hf_involved_all == 1

* log intensities
reghdfe delta_y c.log_int_fi##c.ois_2y c.log_int_macro##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.log_int_fi#c.ois_2y = c.log_int_macro#c.ois_2y

* raw intensities (pp of outstanding): amplification per pp held
reghdfe delta_y c.hf_intensity_fi##c.ois_2y c.hf_intensity_macro##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.hf_intensity_fi#c.ois_2y = c.hf_intensity_macro#c.ois_2y
