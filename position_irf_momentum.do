********************************************************************************
* POSITION-ADJUSTMENT IMPULSE RESPONSES (overnight vs term repo)
* Inputs : Data\monetary_policy_induced_position_overnight.csv  and  ..._term.csv
*          (both built by build\build_maturity_panels.ipynb)
* Produces: Figure 5  (IR_on_momentum, overnight)  and  Appendix Figure (IR_term_momentum, term)
* The overnight/term split (contractual_maturity <= 1 vs > 1) is applied upstream in the
* notebook; here the only change across the two figures is the input panel.
********************************************************************************

foreach seg in overnight term {
    local outfig = cond("`seg'" == "overnight", "IR_on_momentum", "IR_term_momentum")

    import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position_`seg'.csv", clear
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

    graph export "C:\Users\hermesf\Projects\JobMarket\Figures\`outfig'.png", replace width(2400)
}
