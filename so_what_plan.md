# So-What Extensions — Research Plan

*Working notes, July 2026. Response to the recurring seminar feedback ("so what?"). Captures the discussion and decisions so far; to be updated as modules progress.*

## The problem, stated precisely

The identification is not the target of the objection — the economic magnitude is. The headline result is ~1.7bp of extra yield movement that self-reverses within four trading days. There are three generic ways to answer that kind of objection, and they define the three modules below:

1. **When is it big?** Show the effect scales with shock size and/or states (non-linearity).
2. **Who pays?** Show someone bears a *permanent* cost from the *temporary* dislocation.
3. **How does it spread?** Show the mechanism propagates across assets/markets (contagion).

## Decisions already taken

- **Haircut-based convexity evidence: dropped.** The haircut variable is too unstable to carry a result. The non-linearity burden moves to Module 1 (empirical shock-size profile) instead of the funding-terms mechanism.
- **Corporate bond spillovers: off the critical path.** Three stacked problems: long causal chain (shock → specific BTPs → benchmark curve → corporate pricing), diffuse mapping from bond-level HF positioning to any specific corporate's benchmark, and the real-effect version requires corporate primary issuance inside a ~4-day window (tiny, noisy sample). Candidate for a second paper, not the JMP.
- **Sequencing: Module 1 first.** The expanded event universe is an input to the power of Modules 2 and 3.

---

## Module 1: When is it big — shock-size profile from rule-based macro releases

**Goal.** Test linearity vs. convexity of the amplification in shock size, with an event universe selected by rule, not by hand.

**Event universe (the "rule").** All scheduled euro-area macro releases above a pre-specified Bloomberg relevance-score threshold (relevance = share of terminal users with alerts set — an objective selection criterion). Colleague is providing the release file incl. survey-based surprises (actual − Bloomberg median expectation). This yields plausibly 300+ event days vs. 38 ECB meetings, with genuine large-shock support (2021–23 inflation surprises).

**Shock measurement.**
- *Preferred:* intraday change in 2y OIS or Schatz-futures-implied yield in a tight window around the release timestamp — mirrors the EA-MPD design. Open item: intraday history back to 2021 (Bloomberg intraday history limits; check Refinitiv/ECB tick sources).
- *Fallback (respectable, Swanson–Williams precedent):* standardized survey surprise (actual − median, scaled by release-type surprise volatility) as the shock, with a first-stage regression of the daily 2y OIS change on the surprise to convert into bp units comparable to the MP shocks. References: Swanson & Williams (2014, AER 104(10), "Measuring the Effect of the Zero Lower Bound on Medium- and Long-Term Interest Rates") for the daily-frequency, standardized-survey-surprise design pooling many release types; their companion piece Swanson & Williams (2014, JIE 92, "...Yields and Exchange Rates in the United Kingdom and Germany") applies it to German yields. Euro-area counterpart for release selection/relevance: Altavilla, Giannone & Modugno (2017, JME, macro news and bond yields).

**Designs.**
- *Pooled, structured:* existing specification plus `HF × Shock × |Shock|`, or cleaner, shock-size terciles interacted with `HF × Shock`. With 300+ event dates the date-cluster count is no longer binding.
- *Visual companion:* per-event amplification betas (cross-sectional estimate per event day) plotted against |shock|, precision-weighted. Candidate money chart.

**Confounds / robustness.**
- Shock size correlates with volatility regime → re-run on GARCH-standardized yield changes (machinery already built).
- Orthogonality test ports over: lagged aggregate HF positioning must not predict the release surprise.
- Key clarification from discussion: "large events have stronger yield reactions" is not a problem — that is the x-axis. The question is whether the *amplification coefficient per bp of shock* varies with shock size.

### Data notes — Bloomberg calendar files (added after first inspection, July 2026)

Two ECO EZ exports in `BB_calender.zip`: `BB_00_23.xlsx` (2000-01→2023-12, English headers, 12.3k rows) and `BB_23_25.xlsx` (2023-01→2025-10, German headers, incl. relevance score `S`, survey high/low, n estimates, dispersion). Facts established:

- **Consistency:** 100% match of actuals and medians on the 2023 overlap → splice old file (to end-2022) + new file (2023 on) is safe. Ticker universes match (~41 tickers, all mappable to relevance scores via the new file).
- **Coverage:** euro-area *aggregates only* (flag EC). No German/Italian country releases (no ifo), **no US releases**. ECB rate decisions are in the calendar (EURR002W, EUORDEPO, EUORMARG) and must be dropped (already covered by EA-MPD).
- **Frequency:** 2021–2025 window has ~1,466 surveyed release-obs on ~597 dates (~3 releases per release day; release days ≈ 70% of trading days).
- **Bloomberg's surprise column** (`Surprise`/`Überraschung`) is scaled by *cross-forecaster dispersion*, not by the historical std of surprises → recompute per literature convention (see below).
- **Flash vs. final share one ticker** (PMIs, CPI: `Period` suffix P/F) → treat as separate release types (AGM precedent: advance/second/third treated separately).

### Proposed selection rule (to confirm)

1. Surveyed releases only (consensus median exists — no survey, no surprise).
2. Relevance `S` ≥ 50 (robustness: 60, 70). Yields 17 tickers, ~1,077 obs, ~500 release days in-window; days with max |s| ≥ 1σ: ~158, ≥ 2σ: ~62 (vs. 38 MP events). Note: with the two-step shock construction the threshold is near-cosmetic, since first-stage weights ≈ 0 for irrelevant releases.
3. Drop ECB-decision rows; drop release days coinciding with ECB monetary events (contamination; mirrors the CDS-shock treatment).

### Shock construction (daily, no intraday needed — SW/AGM precedent)

1. Raw surprise = actual − median (both files carry the ingredients). Standardize by the **ticker-level time-series σ of raw surprises**, estimated on the long 2000+ history (this is what the old file is for). SW: "normalized by its historical standard deviation"; AGM fn. 4: "sample standard deviation". Do **not** use Bloomberg's dispersion-scaled surprise (disagreement is state-dependent — widens exactly in 2021–22, mechanically shrinking measured surprises when news was largest, and would contaminate the shock-size profile).
2. First stage (AGM Eq. 1 structure): daily Δ2y OIS on all standardized surprises jointly, all days, news=0 on non-release days; non-synchronous releases → no collinearity (AGM fn. 3). γ_k = bp per 1σ of release k.
3. Daily macro shock = Σ_k γ̂_k s_{k,t} (fitted news component, in bp of 2y risk-free news) → drop-in replacement for the MP shock in all specifications; single number per day aggregates simultaneous releases; exogenous by construction (function of surprises only).
4. Robustness shock defs: single highest-relevance release per day in σ units; γ estimated on longer window.

**Known limitation of the daily window + EA-only calendar:** US releases (CPI 14:30 CET) land inside the same euro trading-day close but are absent from the composite → attenuation/noise on those days, not bias (orthogonality of US news to pre-set HF positioning; test extendable). Preferred fix: request ECO US (and ECO GE for ifo) exports from colleague — same download procedure.

**Data still needed:** daily 2y EUR OIS closes 2021–2025 (Bloomberg, one series; optionally 10y as duration-relevant alternative).

**Unscheduled large events** (Mar-2025 German fiscal package ~30bp Bund day, Apr-2025 tariff turmoil, Sep-2022 LDI spillover, Jul-2022 Draghi resignation, Mar-2023 banking stress): once the systematic release-based analysis exists, these become *illustrations* (case-study box), not load-bearing evidence. Case studies are only vulnerable when they carry the result.

**Either outcome is informative.**
- Convex → headline non-linearity result.
- Linear → the ~28% amplification *share* is scale-invariant; stress arithmetic becomes legitimate (e.g., a 30bp repricing event implies ~8–10bp positioning-driven overshoot in HF-held bonds), with Mar-2025 as quasi-out-of-sample validation.

**Side payoffs.** External validity beyond ECB announcements; expands qualifying shock windows for Module 2; additional shock days usable in Module 3.

---

## Module 2: Who pays — sovereign issuance costs at auctions

**Logic.** A temporary dislocation has real effects only for agents who transact during it → primary issuance. Italy and Germany auction on pre-announced calendars, mostly re-openings of lines already in the panel — so the auctioned bond has observed HF positioning. An auction inside the ~4-day overshoot window locks the dislocated yield in permanently. Converts "1.7bp temporary" into € of additional debt service borne by the taxpayer.

**Data.** Public auction results (MEF/Banca d'Italia; Deutsche Finanzagentur): allotment yields, bid-to-cover, tails, Bundesbank retention quotas. Merge by ISIN. Several hundred auctions 2021–2025 across the two issuers.

**Design — continuous treatment, not a binary window dummy.** Assign every auction a *dislocation state* of the auctioned line:
- predicted: recent shock size × pre-auction HF intensity × estimated 4-day decay profile from the LPs; or
- measured: the bond's running yield gap vs. its matched control since the last shock.

Regress auction outcomes on the continuous dislocation measure using **all** auctions. Power comes from variation in dislocation intensity, not from a small treated group.

**Outcome variable.** Auction premium = allotment yield − the bond's own secondary-market mid at the bidding cutoff (standard in the auction literature; strips most noise). Corroborating margins: bid-to-cover, auction tail, retention quota.

**Answer to the "few qualifying dates" worry.** (i) Module 1 expands qualifying windows from 8 ECB meetings/year to any sizable shock day. (ii) The continuous-treatment design uses all auctions regardless.

**Calibrated ambition.** The causal burden stays with the main analysis. This module quantifies: "auctions during dislocation windows priced X bp above matched fair value; applied to €Y bn issued, €Z of additional debt service locked in." Supporting regressions with modest significance are acceptable in that role.

**Literature hooks.** Auction-cycle price pressure: Lou–Yan–Zhang (2013); Beetsma et al. (euro area); Sigaux. Novelty: cross-sectional, positioning-based prediction of *which* auctions get hit.

---

## Module 3: How it spreads — cross-bond contagion through fund portfolios

**Goal.** Show a country-specific shock propagates to *other* sovereigns through the portfolios of exposed funds. Upgrades the headline from "yields overshoot temporarily" to "leverage links transmit stress across sovereign markets." Natural continuation of the directionality result (constraint binds at portfolio level).

**Laboratory.** Italian CDS credit shock (existing residualized measure) → outcome: **German** bond yields within duration×date×country cells. The cells absorb the entire aggregate German response, including flight-to-safety; identification comes from *which* German bonds move.

**Treatment.** Bond-level exposure = holdings-weighted Italy *loss-exposure* of the funds holding each German bond (Greenwood–Thesmar-style vulnerability: sign of the fund's Italian position × shock direction, aggregated to the bond via position weights, measured pre-shock).

**Three causality assets (why feasibility is better than feared).**
1. **Signed cross-sectional prediction.** Exposed funds are typically long BTP / short Bund. Deleveraging after an Italian shock means *buying back* German shorts (those bonds richen relative to peers) and *selling* German longs (cheapen). Opposite-signed responses by position sign — a macro confound would need to know each fund's position in each bond to mimic this.
2. **Quantities are observed.** LP of fund-bond-level German position changes on the shock × fund Italy-exposure — document the rebalancing directly (mirror of the existing intensity IRF figure). Mechanism shown, not asserted.
3. **Dealer confound has ready infrastructure.** Re-run with dealer×date FE on the existing dealer-bond-date panel: compare German bonds at the same dealer differing only in the Italy-exposure of the funds holding them.

**Sector placebo (isolates the HF channel).** Build the identical exposure construct for non-HF repo participants in SFTDS (banks, other funds). Not leverage-constrained the same way → contagion should be absent/weaker through them.

**Standard placebos.** No differential on non-shock days; flat pre-trends.

**Power.** 2% CDS tail ≈ 25 shock days; check 5% threshold (threshold robustness already noted for the direct effect). Reverse-direction case study: Mar-2025 German fiscal shock → do exposed funds' *Italian* holdings move?

---

## Packaging

- The three modules answer the so-what as a set: **when is it big / who pays / how does it spread**.
- Lean harder on the existing directionality index (Fig. holder_dir_ts) as a real-time fragility-monitoring tool computable daily from SFTDS — a concrete policy deliverable that already exists.
- Money-chart candidate: event-level amplification vs. shock size, with the Mar-2025 cross-section highlighted as validation.

## Open items

- [ ] Intraday shock measurement around release timestamps: check Bloomberg intraday history limits back to 2021; Refinitiv/ECB tick alternatives; else daily fallback with first-stage conversion.
- [ ] Fix the release-type list and relevance threshold **ex ante** (the rule must be pre-specified to do its job).
- [ ] Colleague's release/surprise file: ingest and validate against a few known dates.
- [ ] Auction results scraping/merge (MEF, Finanzagentur), ISIN-level.
- [ ] CDS tail threshold (2% vs 5%) for Module 3 power.
- [ ] Optional garnish: MTS/Bloomberg volume data to quantify secondary-market volume transacted inside overshoot windows (aggregate wealth-transfer number).
