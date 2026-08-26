********************************************************************************
* MATCH STABILITY
* Requires: matched_sample.do must have been run in full, so that
*           Data\match_map_dated.dta exists (pair map with business_date
*           and ois_2y). This file only READS intermediates.
* Produces: (a) match turnover statistics; (b) matched regression with each
*           HF bond assigned ONE fixed partner over the whole sample
*           (modal partner and first-ever partner), instead of daily
*           re-matching. Days on which the fixed partner has no data or is
*           itself HF-involved are dropped and counted.
********************************************************************************

clear all

********************************************************************************
* 1. Turnover statistics
********************************************************************************

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map_dated.dta", clear

gen date_num = date(business_date, "YMD")
format date_num %td

* (a) Day-to-day persistence: same partner as on the bond's previous matched day
sort hf_isin date_num
by hf_isin: gen same_as_prev = (nohf_isin == nohf_isin[_n-1]) if _n > 1
summarize same_as_prev

* (b) Announcement-to-announcement persistence: same partner as at the
*     bond's previous announcement day
preserve
    keep if ois_2y != 0
    sort hf_isin date_num
    by hf_isin: gen same_as_prev_shock = (nohf_isin == nohf_isin[_n-1]) if _n > 1
    summarize same_as_prev_shock
restore

* (c) Distinct partners per HF bond, matched days, and modal-partner share
bysort hf_isin nohf_isin: gen first_pair_obs = (_n == 1)
bysort hf_isin nohf_isin: gen pair_days = _N
bysort hf_isin: egen n_partners = total(first_pair_obs)
bysort hf_isin: gen n_days = _N
bysort hf_isin: egen max_pair_days = max(pair_days)
gen modal_share = max_pair_days / n_days

egen tagb = tag(hf_isin)
summarize n_days if tagb, detail
summarize n_partners if tagb, detail
summarize modal_share if tagb, detail

********************************************************************************
* 2. Fixed-partner definitions per HF bond
********************************************************************************

* Modal partner: the control matched on the most days (ties broken by ISIN)
preserve
    collapse (count) pair_days = pair_id, by(hf_isin nohf_isin)
    bysort hf_isin (pair_days nohf_isin): keep if _n == _N
    keep hf_isin nohf_isin
    rename nohf_isin partner_modal
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\partner_modal.dta", replace
restore

* First partner: the control matched on the bond's first matched day
preserve
    sort hf_isin date_num nohf_isin
    by hf_isin: keep if _n == 1
    keep hf_isin nohf_isin
    rename nohf_isin partner_first
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\partner_first.dta", replace
restore

* HF bond-days of the matched sample, with the cell id used for clustering
keep hf_isin business_date duration_match
duplicates drop hf_isin business_date, force
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_days.dta", replace

********************************************************************************
* 3. Slim daily panel for both sides
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
keep isin business_date delta_y ois_2y bid_ask_spread ctd_flag hf_involved
duplicates drop isin business_date, force
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\stability_panel.dta", replace

********************************************************************************
* 4. Fixed-partner matched regressions
********************************************************************************

foreach p in modal first {

    di as text _n "================ fixed partner: `p' ================"

    use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_days.dta", clear
    merge m:1 hf_isin using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\partner_`p'.dta", ///
        keep(match) nogenerate

    * Two rows per HF bond-day: the HF bond and its fixed partner
    expand 2
    bysort hf_isin business_date: gen treated = (_n == 1)
    gen isin = cond(treated == 1, hf_isin, partner_`p')

    merge m:1 isin business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\stability_panel.dta", ///
        keep(match) nogenerate

    * Drop pair-days where the partner is missing or itself HF-involved
    quietly count
    local n_rows_raw = r(N)
    gen bad_control = (treated == 0 & hf_involved == 1)
    bysort hf_isin business_date: egen drop_contaminated = max(bad_control)
    bysort hf_isin business_date: gen npair = _N
    quietly count if drop_contaminated == 1 & treated == 1
    di as text "pair-days dropped, partner HF-involved : " as result r(N)
    quietly count if npair < 2 & treated == 1
    di as text "pair-days dropped, partner no data     : " as result r(N)
    drop if drop_contaminated == 1 | npair < 2
    quietly count if treated == 1
    di as text "pair-days retained                     : " as result r(N)

    gen pairday = hf_isin + "_" + business_date
    gen nohf_isin = partner_`p'

    reghdfe delta_y c.treated##c.ois_2y ctd_flag, ///
        absorb(pairday) vce(cluster duration_match nohf_isin)
}
