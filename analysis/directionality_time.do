********************************************************************************
* DIRECTIONALITY VS CALENDAR TIME  (discussant slide 20)
* Standalone: re-imports the CSV and rebuilds holder_dir_pre exactly as
* directionality.do does (5-day trailing mean over prior active days).
* Produces: (a) composition of the hedged/directional groups by year, all
*               days and announcement days only, for the appendix;
*           (b) same-date identification: directionality effects with
*               HF-presence x date fixed effects, so every date carries its
*               own baseline HF-vs-non-HF sensitivity and directionality is
*               identified only from differences among HF bonds on the SAME
*               date. Calendar-time variation cannot drive these estimates.
********************************************************************************

clear all

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* holder_dir_pre: 5-day trailing mean over prior active days (as in
* directionality.do)
gen hd_sum = 0
gen hd_cnt = 0
forvalues k = 1/5 {
    replace hd_sum = hd_sum + L`k'.holder_dir if !missing(L`k'.holder_dir)
    replace hd_cnt = hd_cnt + 1              if !missing(L`k'.holder_dir)
}
gen holder_dir_pre = hd_sum / hd_cnt if hd_cnt > 0
drop hd_sum hd_cnt

gen present = (hf_intensity_pre > 0)
gen hd = holder_dir_pre
replace hd = 0 if present == 0

* Pooled median among HF bond-days (as in Table IX)
sum holder_dir_pre if present, detail
scalar hd_med = r(p50)

gen hf_dir3 = 0
replace hf_dir3 = 1 if present & holder_dir_pre <= hd_med & !missing(holder_dir_pre)
replace hf_dir3 = 2 if present & holder_dir_pre >  hd_med & !missing(holder_dir_pre)
replace hf_dir3 = . if present & missing(holder_dir_pre)
label define hf_dir3_lbl 0 "No HF" 1 "Hedged-held" 2 "Directional-held"
label values hf_dir3 hf_dir3_lbl

* Drop HF bond-days without a defined directionality (mirrors the Table IX
* estimation sample, where these rows drop through i.hf_dir3 == .)
drop if present & missing(holder_dir_pre)

gen year = year(date_num)

********************************************************************************
* (a) Composition of the groups over time
********************************************************************************

di as text _n "==== group membership by year, all bond-days (column shares) ===="
tab year hf_dir3 if inlist(hf_dir3, 1, 2), col

di as text _n "==== group membership by year, announcement days only ===="
tab year hf_dir3 if inlist(hf_dir3, 1, 2) & ois_2y != 0, col

di as text _n "==== holder directionality by year, HF bond-days ===="
tabstat holder_dir_pre if present, by(year) stat(mean p50 sd n)

********************************************************************************
* (b) Same-date identification: HF-presence x date fixed effects
********************************************************************************

* Each (HF presence x date) pair gets its own fixed effect. Because the shock
* is constant within a date, these absorb both the level and the shock
* response of HF bonds relative to non-HF bonds date by date. What remains
* identified is the difference among HF bonds on the same date.
egen hf_date = group(present business_date)

* Directional dummy, pooled cutoff (zero for hedged and for no-HF bonds)
gen dir_pooled = (hf_dir3 == 2)

* Directional dummy, cutoff formed within each date among HF bonds
bysort business_date: egen hd_med_day = ///
    median(cond(present & !missing(holder_dir_pre), holder_dir_pre, .))
gen dir_withinday = (present & holder_dir_pre > hd_med_day & !missing(holder_dir_pre))

* (1) Reference: Table IX Column (2) specification, pooled cutoff, no HF x date FE
reghdfe delta_y i.hf_dir3##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_dir3#c.ois_2y = 2.hf_dir3#c.ois_2y

* (2) HF x date FE, pooled cutoff: directional-vs-hedged from same-date
*     differences among HF bonds
reghdfe delta_y c.dir_pooled##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

* (3) HF x date FE, within-date cutoff
reghdfe delta_y c.dir_withinday##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

* (4) Continuous triple interaction (Table IX Column (1) analog) with
*     HF x date FE
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hd c.log_hf_intensity#c.ois_2y#c.hd ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin hf_date) vce(cluster business_date isin)

********************************************************************************
* (c) Announcement-level regime test: does the amplification slope rise with
*     the sector's aggregate directionality?
*     Uses the daily matched differential built by announcement_evidence.do
*     (Data\daily_differential.dta must exist). The time-series margin is
*     where the directionality variation lives; this is the honest home of
*     the regime claim. 38 observations.
********************************************************************************

* Aggregate pre-shock directionality per date, position-weighted (mirrors the
* construction of Figure 6, but with the predetermined trailing measure)
gen gross_w = gross_long + gross_short
preserve
    keep if present & !missing(holder_dir_pre) & gross_w > 0
    collapse (mean) agg_dir = holder_dir_pre [aw = gross_w], by(business_date)
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\agg_dir.dta", replace
restore

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", clear
merge 1:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\agg_dir.dta", ///
    keep(match master) nogenerate
keep if is_ann

* Center aggregate directionality so the ois_2y coefficient is the
* amplification slope at the average announcement-day directionality
summarize agg_dir
gen agg_dir_c = agg_dir - r(mean)
gen s_x_dir = ois_2y * agg_dir_c

reg D ois_2y s_x_dir agg_dir_c, robust
