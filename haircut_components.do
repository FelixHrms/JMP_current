********************************************************************************
* HAIRCUT COMPONENT DECOMPOSITION
* Input : Data\haircut_cells.csv   (built by diagnostics_haircuts.ipynb)
* Decomposes the repo MARGIN into fund, dealer, and collateral components via
* multi-way fixed effects (AKM-style), pooling both legs and both countries.
* Exports: Data\haircut_fund_fe.csv, Data\haircut_dealer_fe.csv,
*          Data\haircut_bond_fe.csv   (components to merge into the
*          amplification panel in the next step)
********************************************************************************

clear all
set more off

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\haircut_cells.csv", clear

*-------------------------------------------------------------------------------
* Dependent variable: |haircut| = the margin protecting the dealer.
* Long  (fund borrows cash):  h > 0 protects the cash-lending dealer.
* Short (fund lends cash):    h < 0 protects the collateral-lending dealer.
* In BOTH legs leverage rises as the margin falls toward zero, so |h| is the
* single leg-consistent measure. Lower |h| => more fund leverage.
*-------------------------------------------------------------------------------
gen abs_haircut = abs(haircut)
drop if missing(abs_haircut)

* Keys (group() is robust to string/numeric ids; original ids kept for exports)
egen fund   = group(fund_id)
egen dealer = group(dealer_id)
egen bond   = group(isin)
egen leg_id = group(leg)
gen date_num = date(substr(business_date, 1, 10), "YMD")
format date_num %td

*===============================================================================
* 1. DECOMPOSITION   |haircut| = a_fund + d_dealer + k_bond + t_date + leg + e
*    Fund and dealer effects are jointly identified within the connected
*    fund-dealer component (the diagnostics show one component covering ~100%).
*    Use [aw=nominal_euro] instead for a volume-weighted variant.
*===============================================================================
reghdfe abs_haircut i.leg_id, ///
    absorb(fund_fe=fund dealer_fe=dealer bond_fe=bond date_fe=date_num) ///
    resid vce(cluster fund)

gen double resid_h = _reghdfe_resid
display "R2 (with FE) = " %5.3f e(r2) "   within-R2 = " %5.3f e(r2_within)

*===============================================================================
* 2. VARIANCE DECOMPOSITION of the margin
*    var(|h|) = var(fund)+var(dealer)+var(bond)+var(date)+2*cov(.)+var(resid)
*    Own-variance shares below do NOT sum to 1; the remainder is the covariance
*    (sorting) terms. NB: with few dealers, var(fund)/var(dealer) carry the
*    usual AKM limited-mobility bias - read as indicative magnitudes.
*===============================================================================
quietly sum abs_haircut if e(sample)
scalar v_tot = r(Var)
di _n "=== Own-variance shares of |haircut| ==="
foreach c in fund_fe dealer_fe bond_fe date_fe resid_h {
    quietly sum `c' if e(sample)
    di %-10s "`c'" "   " %6.3f (r(Var)/v_tot)
}
di _n "Spread of the components (sd, p10, p90):"
tabstat fund_fe dealer_fe bond_fe if e(sample), stat(sd p10 p90) col(stat)
di _n "Fund-dealer sorting:"
corr fund_fe dealer_fe if e(sample)

*===============================================================================
* 3. EXPORT COMPONENTS (one value per id; constant within id)
*===============================================================================
preserve
    keep if e(sample)
    collapse (mean) fund_fe (count) n_obs = abs_haircut, by(fund_id)
    export delimited using "C:\Users\hermesf\Projects\JobMarket\Data\haircut_fund_fe.csv", replace
restore

preserve
    keep if e(sample)
    collapse (mean) dealer_fe (count) n_obs = abs_haircut, by(dealer_id)
    export delimited using "C:\Users\hermesf\Projects\JobMarket\Data\haircut_dealer_fe.csv", replace
restore

preserve
    keep if e(sample)
    collapse (mean) bond_fe (count) n_obs = abs_haircut, by(isin)
    export delimited using "C:\Users\hermesf\Projects\JobMarket\Data\haircut_bond_fe.csv", replace
restore

*===============================================================================
* 4. BOND-DAY COMPONENT CONTRIBUTIONS (position-weighted) for the amplification
*    stage. margin = |haircut|; resid_comp is the part of the margin orthogonal
*    to fund, dealer, bond, date and leg -> the leverage "counterfactual".
*===============================================================================
preserve
    keep if e(sample)
    gen double margin = abs_haircut
    collapse (mean) margin fund_comp=fund_fe dealer_comp=dealer_fe ///
        bond_comp=bond_fe resid_comp=resid_h [aw=nominal_euro], ///
        by(business_date isin)
    export delimited using "C:\Users\hermesf\Projects\JobMarket\Data\haircut_bondday.csv", replace
restore
