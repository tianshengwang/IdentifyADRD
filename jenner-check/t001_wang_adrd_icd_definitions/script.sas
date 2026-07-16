/**********************************************************************************************************
 * Adapted for Jenner from: SAS/ADRD definitions.sas (tianshengwang/IdentifyADRD)
 * Original author: Virginia Pate
 * Purpose: ICD9/ICD10 code lists used to build the Jain, Bynum, Lee and Wang dementia
 *          identification algorithms (as published in Wang T, et al. Am J Epidemiol. 2025).
 *
 * Adaptation for this bundle:
 *   - The original reads `dx.dx` and `dx10.dx10` from a site LIBNAME pointing at a restricted
 *     institutional ICD reference library (M:\cvd_associates_projects\...). Those tables are
 *     recreated here in miniature via DATALINES, containing the exact ICD9/ICD10 dementia codes
 *     the Wang/Jain/Bynum/Lee definitions filter on, plus a handful of unrelated codes so the
 *     `where code in:` filters have something to reject.
 *   - `covref`, `adrdref` output librefs point at WORK instead of the original network shares.
 *   - The DATA steps below (lines 42-137 of the source file) are otherwise untouched: same
 *     WHERE code lists, same derived flags (wang_primary, wang_secondary, jain_primary,
 *     jain_extended, bynum, lee). See meta.json for one line excluded from this bundle.
 *   - The %dx() and %getndc() macros (unused / drug-NDC lookup) are out of scope for this bundle.
 **********************************************************************************************************/

libname adrdref (work);

/* Mock of dx.dx: ICD-9-CM diagnosis code reference (code, description) */
data dx_dx;
	length code $8 description $60;
	input code $ description & $60.;
	datalines;
3310 Alzheimers disease
2900 Senile dementia uncomplicated
2901 Presenile dementia
2902 Senile dementia with delusional features
2903 Senile dementia with depressive features
2904 Vascular dementia
2908 Senile dementia with mood disturbance
2909 Unspecified senile psychotic condition
2940 Amnestic syndrome
2941 Dementia in conditions classified elsewhere
2942 Dementia unspecified without behavioral disturbance
2948 Other persistent mental disorders
3311 Pick disease
3312 Senile degeneration of brain
3317 Cerebral degeneration in diseases classified elsewhere
33182 Dementia with Lewy bodies
33189 Other cerebral degeneration
3319 Cerebral degeneration unspecified
797  Senility without mention of psychosis
25000 Diabetes mellitus type II
4019  Essential hypertension
;
run;

/* Mock of dx10.dx10: ICD-10-CM diagnosis code reference (code, short_description) */
data dx10_dx10;
	length code $8 short_description $60;
	input code $ short_description & $60.;
	datalines;
G300 Alzheimers disease with early onset
G301 Alzheimers disease with late onset
G308 Other Alzheimers disease
G309 Alzheimers disease unspecified
F0150 Vascular dementia without behavioral disturbance
F0151 Vascular dementia with behavioral disturbance
F0280 Dementia in other diseases without behavioral disturbance
F0281 Dementia in other diseases with behavioral disturbance
F0390 Unspecified dementia without behavioral disturbance
F0391 Unspecified dementia with behavioral disturbance
F04  Amnestic disorder due to known physiological condition
R4181 Age related cognitive decline
G3101 Pick disease
G3109 Frontotemporal dementia unspecified
G311 Cerebral degeneration primary
G312 Degeneration of nervous system due to alcohol
G3183 Dementia with Lewy bodies
G94  Other disorders of brain in diseases classified elsewhere
F068 Other specified mental disorders due to known condition
E119  Type 2 diabetes mellitus without complications
I10   Essential primary hypertension
;
run;

libname dx (work);
libname dx10 (work);
data dx.dx; set dx_dx; run;
data dx10.dx10; set dx10_dx10; run;


/*DIAGNOSES*/

*Jain;
data adrdref.jain_adrd_icd9dx;
	set dx.dx;
	where code in: (/*primary definition*/ '3310' '2900' '2901' '2902' '2903' '2904' '2940' '2941' '2942' '2948' '797'
					/*extended definition*/ '3311' '3312' '3317' '33182' '33189' '3319' '2908' '2909' '2949');

	if code in: ('3310' '2900' '2901' '2902' '2903' '2904' '2940' '2941' '2942' '2948' '797') then jain_primary=1; *primary = primary analyses;
	jain_extended=1;*extended=sensitivity analysis;
	keep code description jain_primary jain_extended;
run;


data adrdref.jain_adrd_icd10dx;
	set dx10.dx10(rename=(short_description=description));
	where code in: (/*primary definition*/ 'G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181'
					/*extended definition*/ 'G3101' 'G3109' 'G311' 'G3183' 'G3189' 'G319' 'G138' 'G94' 'F068');

	if code in: ('G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181') then jain_primary=1;
	jain_extended=1;
	keep code description jain_primary jain_extended;
run;


*Bynum;
data adrdref.bynum_adrd_icd9dx;*331.9, 290.9, 294.9 not included;
	set dx.dx;
	where code in: ('3310' '3311' '3312' '3317' '33182' '33189' '2900' '2901' '2902' '2903' '2904' '2908' '2940' '2941' '2942' '797');

	bynum=1;
	keep code description bynum;
run;

*12/2/2024 - switch to published Bynum ICD-10 code list;
data adrdref.bynum_adrd_icd10dx;
	set dx10.dx10(rename=(short_description=description));
	where code in: ('F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'G300' 'G301' 'G308' 'G309'
					'G3101' 'G3109' 'G3183' 'G311' 'G312' 'R4181');

	bynum=1;
	keep code description bynum;
run;


*Lee;
data adrdref.lee_adrd_icd9dx;*331.82, 331.89, 331.9, 290.8, 290.9, 294.9 not included (from Jain);
	set dx.dx;
	where code in: ('2900' '2901' '2902' '2903' '2904' '2940' '2941' '2942' '2948' '3310' '3311' '3312' '3317' '797');

	lee=1;
	keep code description lee;
run;

data adrdref.lee_adrd_icd10dx;*G31.83, G31.89, G31.9 not included;
	set dx10.dx10(rename=(short_description=description));
	where code in: ('G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181'
					'G3101' 'G3109' 'G311' 'G138' 'G94' 'F068');

	lee=1;
	keep code description lee;
run;



*Wang;
*9/28/2023 -- flag 4 secondary codes, remove 294.8, 797, 331.9, 290.9 from definition;
data adrdref.wang_adrd_icd9dx;
	set dx.dx;
	where code in: ('3310' '2900' '2901' '2902' '2903' '2904' '2940' '2941' '2942'
					'3311' '3312' '3317' '33182');
	wang=1;

	if code in: ('29011' '2903' '29041' '2940') then wang_secondary=1; else wang_secondary=0;

	keep code description wang wang_secondary;
run;


data adrdref.wang_adrd_icd10dx;
	set dx10.dx10(rename=(short_description=description));
	where code in: ('G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181'
					'G3101' 'G3109' 'G311' 'G3183');

	wang=1; wang_primary=1; wang_secondary=0;
	keep code description wang wang_primary wang_secondary;
run;


title "Wang ADRD ICD-9 diagnosis codes (secondary-code flag)";
proc print data=adrdref.wang_adrd_icd9dx noobs; run;

title "Wang ADRD ICD-10 diagnosis codes";
proc print data=adrdref.wang_adrd_icd10dx noobs; run;

title "Jain vs Bynum vs Lee vs Wang ICD-9 code counts";
proc sql;
	select 'jain_icd9' as algorithm, count(*) as n_codes from adrdref.jain_adrd_icd9dx
	union all
	select 'bynum_icd9', count(*) from adrdref.bynum_adrd_icd9dx
	union all
	select 'lee_icd9', count(*) from adrdref.lee_adrd_icd9dx
	union all
	select 'wang_icd9', count(*) from adrdref.wang_adrd_icd9dx;
quit;
title;
