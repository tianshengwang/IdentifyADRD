/**********************************************************************************************************
 * Adapted for Jenner from: SAS/03e_ADRD_outcomes_Wang.sas (tianshengwang/IdentifyADRD)
 * Original author: Virginia Pate; algorithm published in Wang T, et al. "Developing A Novel
 * Algorithm to Identify Incident and Prevalent Dementia in Medicare Claims. The ARIC Study."
 * Am J Epidemiol. 2025 Aug 4.
 *
 * This bundle exercises the paper's final incident-dementia outcome definition (source lines
 * 298-315) unmodified: "Final Outcome Variable = Scenario 1B (2 ADRD dx claims within 1-year)
 * OR Scenario 5 (1 ADRD dx with new rx within +/-90-days)".
 *
 * Adaptation: in the source, `adrd_s1b` and `adrd_s5_6` are themselves built upstream (STEP 1/
 * SCENARIOS 1B/5-6, source lines 111-294) by PROC SQL self-joins against `all_dx`/`all_rx`,
 * which in turn come from restricted CMS claims libraries (der.alldx, raw.pde_saf_file&yr) on a
 * site network share. Rather than recreate that multi-table claims pipeline, this bundle
 * supplies `adrd_s1b` and `adrd_s5_6` directly via DATALINES (read with explicit @n column
 * pointers) -- i.e. it starts from the two scenario tables the upstream macros are documented
 * (in the header comment) to produce, with a mix of beneficiaries satisfying Scenario 1B only,
 * Scenario 5 only, both, or neither. The DATA step below -- the MERGE, the BY, the "Scenario 1B
 * or 5" OUTPUT logic, the MIN() date combination, the KEEP list -- is copied verbatim from the
 * source.
 **********************************************************************************************************/

data adrd_s1b;
	input @1 bene_id $9. @11 indexdate date9. @21 adrd_s1b_dt1 date9. @31 adrd_s1b_dt date9.;
	format indexdate adrd_s1b_dt1 adrd_s1b_dt date9.;
	datalines;
100000001 01JAN2015 15MAR2015 20SEP2015
100000003 01MAR2015 05JUN2015 01SEP2015
;
run;
proc sort data=adrd_s1b; by bene_id indexdate; run;

data adrd_s5_6;
	input @1 bene_id $9. @11 indexdate date9. @21 adrd_s5_dt date9. @31 adrd_s6_dt date9.;
	format indexdate adrd_s5_dt adrd_s6_dt date9.;
	datalines;
100000002 01FEB2015 10APR2015 10APR2015
100000003 01MAR2015 .         01SEP2015
100000005 01MAY2015 15JUN2015 15JUN2015
;
run;
proc sort data=adrd_s5_6; by bene_id indexdate; run;

/* MERGE OUTCOMES - DEFINE FINAL OUTCOME VARIABLE  (source lines 298-315, verbatim) */
/* Final Outcome Variable = Scenario 1B (2 ADRD dx claims within 1-year)
                         OR Scenario 5 (1 ADRD dx with new rx within +/-90-days ) */

data adrd_wang_outcome;
	merge adrd_s1b adrd_s5_6;
	by bene_id indexdate;

	*Algorithm 8: Scenario 1B or 5;
	if adrd_s1b_dt ne . or adrd_s5_dt ne . then do;
		adrd_dxOnly_dt = adrd_s1b_dt;
		adrd_wang_dt = min(adrd_s1b_dt, adrd_s5_dt);
		output;
	end;

	format adrd_wang_dt adrd_dxOnly_dt date9.;
	keep bene_id indexdate adrd_wang_dt adrd_dxOnly_dt;
run;

title "Wang final incident-dementia outcome: Scenario 1B OR Scenario 5";
proc print data=adrd_wang_outcome noobs; run;
title;
