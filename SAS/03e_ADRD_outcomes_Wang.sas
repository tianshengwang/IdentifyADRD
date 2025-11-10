/**************************************************************************************************/
/* Program Name: 03e_ADRD_outcomes_Wang.sas                                                       */
/* Purpose: Incident ADRD algorithm                                                               */
/* Author: Virginia Pate                                                                          */
/* Input data: TRAIN.ADRD_COHORT, TRAIN.COGDIAG_CMS_FINAL                                         */
/* Output data: TRAIN.ADRD_COHORT_INCIDENCE                                                       */
/*                                                                                                */
/* Algorithm:                                                                                     */
/*   Scenario 1: Dementia code followed by a second dementia code at least one day apart, within  */
/*               1-year of each other.  At least one of the codes must be a primary code.         */
/*               Both dementia diagnosis dates are kept - date of dementia diagnosis TBD.         */
/*                                                                                                */
/*   Scenario 4: Dementia code followed by a new Rx in the next 90 days and not preceded by such  */                      
/*               Rx in 180 days prior to Dx                                                       */
/*                                                                                                */
/**************************************************************************************************/

options sasautos=(SASAUTOS "/local/projects/medicare/adrd/programs/macros");


/* STEP 0. PULL COHORT OF INTEREST */

%macro drugs(drug1=, drug2=);
	%GLOBAL drugA drugB;
	%IF &sysparm ^=  %THEN %DO;
		%LET drugA = %UPCASE(%SCAN(&sysparm,1,_));
		%LET drugB = %UPCASE(%SCAN(&sysparm,2,_));
	%END;
	%ELSE %DO;
		%LET drugA = %UPCASE(&drug1);
		%LET drugB = %UPCASE(&drug2);
	%END;
%mend;
%drugs(drug1=Liraglutide, drug2=dpp)
/*%drugs(drug1=metformin, drug2=dpp)*/
%LET startYear=2010;
%LET endYear=2019;
/*%LET startYear=2013;
%LET endYear=2019;*/

%setup(full, 03e_ADRD_outcomes_Wang_&drugA._&drugB, saveLog=Y);


proc sql; 
	create table cohort as select distinct a.bene_id, a.indexdate 
		from out.newusers_&drugA.v&drugB as a 
			inner join out.ie_&drugA._&drugB as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate; 
quit;


/* STEP 1: PULL DIAGNOSIS CODES FOR ADRD WANG ALGORITHM OUTCOME */

%macro get_claims(startYr=&startYear, endYr=&endYear);
	data adrd_ref;  length code $20; 
		set outref.wang_adrd_icd9dx(in=w9) outref.wang_adrd_icd10dx(in=w10);
		if w9 then version='9'; else if w10 then version='0'; 

		if w9 or w10 then wang=1; else wang=0;
		if w10 then wang10=1; else wang10=0;

		if w10 and wang_secondary then wang_secondary10=1; else wang_secondary10=0;
		if w10 and wang_primary then wang_primary10=1; else wang_primary10=0;
	run;

	proc sql;
      	create table all_dx as 
			select distinct a.*, b.from_dt as dx_dt format=date9., b.clm_id, b.source, 
				c.wang, c.wang_primary, c.wang_secondary, c.wang10, c.wang_primary10, c.wang_secondary10

			from cohort as a
				inner join der.alldx as b on a.bene_id=b.bene_id and a.indexdate<b.from_dt
            inner join adrd_ref(where=(version='9')) as c on b.dx=c.code

			union all corresponding

			%DO yr=2015 %TO &endYr;

				select distinct a.*, b.from_dt as dx_dt format=date9., b.clm_id, b.source,
					c.wang, c.wang_primary, c.wang_secondary, c.wang10, c.wang_primary10, c.wang_secondary10

	         from cohort as a 
	            inner join der.alldx10&yr as b on a.bene_id=b.bene_id and a.indexdate<b.from_dt
	            inner join adrd_ref(where=(version='0')) as c on b.dx&yr=c.code

			%IF &yr<&endYr %THEN union all corresponding; %END;

			order by bene_id, dx_dt;               
   quit;
%mend;
%get_claims()



/*   Scenario 1A (candidate algorithm 1 in Table 1): one single dementia code except 4 non-specfic ICD9 codes (29011, 2903, 29041, 2940)
				 The dementia diagnosis date was set as the date of service associated with the dementia codes*/
/*proc sql;*/
/*	create table adrd_s1a as select distinct bene_id, indexdate, */
/*			min(dx_dt) as adrd_s1a_dt format=date9. label='Scenario 1A: First ADRD diagnosis'*/
/*	from all_dx(where=(wang_primary=1))*/
/*	group by bene_id, indexdate*/
/*	order by bene_id, indexdate;*/
/*quit;*/




/*   Scenario 1B (candidate algorithm 2 in Table 1): Dementia code followed by a second dementia code at least one day apart.
                 The dementia diagnosis date set as the date of the second dementia code. 
				 RELAX the "non-specfic 4 codes", i.e., allow theose 4 codes, our original one which may get a 43% sensitivity */

%macro s1b(gap=365);
	proc sql;
		create table adrd_s1b as 
		select distinct * from (
			select distinct a.bene_id, a.indexdate, 
				a.dx_dt as adrd_s1b_dt1 format=date9. label='Scenario 1B: First of 2 ADRD diagnoses',
				min(b.dx_dt) as adrd_s1b_dt format=date9. label='Scenario 1B: Second of 2 ADRD diagnoses'
			from all_dx(where=(wang=1)) as a 
				inner join all_dx(where=(wang=1)) as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate
					and a.dx_dt<b.dx_dt<=a.dx_dt+&gap
			group by a.bene_id, a.indexdate, a.dx_dt)
		group by bene_id, indexdate 
		having adrd_s1b_dt = min(adrd_s1b_dt) 
		order by bene_id, indexdate;
	quit;
%mend;
%s1b()





/*   Scenario 1C (candidate algorithm 4 in Table 1): Dementia code followed by a second dementia code at least one day apart.  The    */
/*               dementia diagnosis date set as the date of the second dementia code. 
                 require at least one is not one-specific 4 codes            */
%macro s1c(gap=365);
	proc sql;
		create table adrd_s1c1 as 
		select distinct a.bene_id, a.indexdate, a.dx_dt as dx_dt1 format=date9., 
			max(a.wang_primary=1) as primary1, max(a.wang_secondary=1) as secondary1,

			min(case when a.wang_primary=1 then b.dx_dt else . end) as primary1_dx_dt2 format=date9.,
			min(case when a.wang_primary=0 and b.wang_primary=1 then b.dx_dt else . end) as secondary1_dx_dt2 format=date9.,

			min(calculated primary1_dx_dt2, calculated secondary1_dx_dt2) as dx_dt2 format=date9.

		from all_dx(where=(wang=1)) as a left join all_dx(where=(wang=1)) as b
			on a.bene_id=b.bene_id and a.indexdate=b.indexdate and a.dx_dt<b.dx_dt<=a.dx_dt+&gap
		group by a.bene_id, a.indexdate, a.dx_dt
		having dx_dt2 ne .
		order by bene_id, indexdate, dx_dt1;
	quit;

	proc sql;
		create table adrd_s1c as select bene_id, indexdate,
				dx_dt1 as adrd_s1c_dt1 format=date9. label='Scenario 1C: First of 2 ADRD diagnoses (at least one specific code)', 
				dx_dt2 as adrd_s1c_dt format=date9. label='Scenario 1C: Second of 2 ADRD diagnoses (at least one specific code)'
			from adrd_s1c1
			group by bene_id, indexdate
			having dx_dt1 = min(dx_dt1)
			order by bene_id, indexdate;
	quit;
%mend;
/*%s1c()*/






%macro merge_s1(timept=inc_vis6, libn=full, version=);
	data adrd_s1;
		merge adrd_s1a adrd_s1b adrd_s1c;
		by bene_id indexdate;

		adrd_wang_s1a = (adrd_s1a_dt>.z);
		adrd_wang_s1b = (adrd_s1b_dt>.z);
		adrd_wang_s1c = (adrd_s1c_dt>.z);
	run;
%mend;

/*%merge_s1()*/





 

/* STEP 2: ADD PDE CLAIMS */

%macro get_pde_claims(startYr=&startYear, endYr=&endYear);
	data rx_ref;  
		set outref.adrd_ndc(in=a) outref.ad_ndc(in=b);
		adrd=a; ad=b;
	run;

	proc sql;
      	create table all_rx as select a.*, d.abdanystartdt, d.abdanyenddt
			from (%DO yr=&startYr %TO &endYr;
				select distinct a.*, c.adrd, c.ad, c.drug, b.srvc_dt as rx_dt format=date9.

				from cohort as a
					inner join raw.pde_saf_file&yr as b on a.bene_id=b.bene_id and a.indexdate<b.srvc_dt
					inner join rx_ref as c on b.prdsrvid = c.ndc11

				%IF &yr<&endYr %THEN union corresponding; %END;) as a
			inner join der.enrlper_abdany as d on a.bene_id=d.bene_id and d.abdanystartdt<=a.rx_dt<=d.abdanyenddt
			order by bene_id, indexdate, rx_dt;               
   quit;
%mend;
%get_pde_claims()
	*No claims for AD drugs at this time - all are newer than our data;




/* SCENARIO 4: (NEW) PRESCRIPTION CLAIM AFTER ADRD DIAGNOSIS */

%macro s4(bl_norx=180, fup_rx=90);
	proc sql;
		create table adrd_s4 as 
		select distinct bene_id, indexdate,
			min(rx_&fup_rx._dt) as adrd_s4a_dt format=date9. label="First ADRD Rx within &fup_rx-days of an ADRD Dx",
			min(case when numRX_preDX&bl_norx=0 and rx_&fup_rx._dt = rx_enroll_&fup_rx._dt then rx_&fup_rx._dt else . end) as adrd_s4_dt format=date9. label="First NEW ADRD Rx within &fup_rx-days of an ADRD Dx",

			case when calculated adrd_s4a_dt ne . then 1 else 0 end as adrd_wang_s4a label="Scenario 4A: ADRD Dx followed by an ADRD Rx within &fup_rx-days",
			case when calculated adrd_s4_dt ne . then 1 else 0 end as adrd_wang_s4 label="Scenario 4: ADRD DX followed by a new (&bl_norx-days) ADRD Rx within &fup_rx-days"

		from (
			select distinct a.bene_id, a.indexdate, a.dx_dt, 

				count(distinct case when a.dx_dt-&bl_norx<=b.rx_dt<a.dx_dt then b.rx_dt else . end) as numRx_preDX&bl_norx label="Number of ADRD Rx in &bl_norx-days prior to ADRD Dx",
				min(case when a.dx_dt<=b.rx_dt<=a.dx_dt+&fup_rx then b.rx_dt else . end) as rx_&fup_rx._dt format=date9. label="First ADRD Rx within &fup_rx-days of an ADRD Dx",
				min(case when .z<b.abdanystartdt+&bl_norx<=b.rx_dt then b.rx_dt else . end) as rx_enroll_&fup_rx._dt format=date9. label="First ADRD Rx with &fup_rx-days of Part D enrollment"

			from all_dx(where=(wang=1)) as a
				inner join all_rx as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate and a.dx_dt-&bl_norx<=b.rx_dt<=a.dx_dt+&fup_rx
			group by a.bene_id, a.indexdate, a.dx_dt)
		group by bene_id, indexdate
		having adrd_wang_s4a=1
		order by bene_id, indexdate;
	quit;
%mend;
/*%s4()*/






/* SCENARIOS 5 AND 6: (NEW (S5)) PRESCRIPTION CLAIM WITHIN 90-DAYS OF (BEFORE OR AFTER) FIRST ADRD DIAGNOSIS */

%macro s5_6(bl_norx=180, rx_window=90);
	*Get date of first rx within 90-days of dx;
	proc sql;
		create table adrd_s5_6a as 
			select distinct a.bene_id, a.indexdate, a.dx_dt, 

				min(b.rx_dt) as rx_dx&rx_window._dt format=date9. label="Date of first ADRD Rx that occurs within &rx_window.-days of first ADRD Dx",
				min(case when b.abdanystartdt+&bl_norx<=b.rx_dt<=b.abdanyenddt then b.rx_dt else . end) as rx_enroll_dx&rx_window._dt format=date9. label="Date of first ADRD Rx that occurs within &rx_window.-days of first ADRD Dx AND has &bl_norx days of enrollment",

 				case when calculated rx_enroll_dx&rx_window._dt ne . then max(a.dx_dt, calculated rx_enroll_dx&rx_window._dt) end as s5_dt format=date9., 
				case when calculated rx_dx&rx_window._dt ne . then max(a.dx_dt, calculated rx_dx&rx_window._dt) else . end as s6_dt format=date9., 
				case when calculated rx_dx&rx_window._dt = calculated rx_enroll_dx&rx_window._dt then 1 else 0 end as potential_new_rx

			from all_dx(where=(wang=1)) as a
				inner join all_rx as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate and a.dx_dt-&rx_window<=b.rx_dt<=a.dx_dt+&rx_window
			group by a.bene_id, a.indexdate, a.dx_dt
			order by bene_id, indexdate, dx_dt;
	quit;

	*Check whether that rx was a new rx;
	proc sql;
		create table adrd_s5_6 as select distinct bene_id, indexdate,
			min(case when new_rx=1 then s5_dt else . end) as adrd_s5_dt format=date9. label="Scenario 5: NEW (&bl_norx-day WP) ADRD Rx within &rx_window-days of ADRD Dx",
			min(s6_dt) as adrd_s6_dt format=date9. label="Scenario 6: ADRD Rx within &rx_window-days of ADRD Dx",

			case when calculated adrd_s5_dt ne . then 1 else 0 end as adrd_wang_s5 label="Scenario 5: ADRD Dx followed by a new (&bl_norx-day WP) ADRD Rx within &rx_window-Days",
			case when calculated adrd_s6_dt ne . then 1 else 0 end as adrd_wang_s6 label="Scenario 6: ADRD Dx followed by an ADRD Rx within &rx_window-Days"

		from
			( select distinct a.*,
					max(b.rx_dt ne .) as prevalent_rx, case when a.potential_new_rx=1 and calculated prevalent_rx=0 then 1 else 0 end as new_rx
			  from adrd_s5_6a as a
			  	 left join all_rx as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate and a.rx_dx&rx_window._dt-&bl_norx<=b.rx_dt<a.rx_dx&rx_window._dt
			  group by a.bene_id, a.indexdate, a.dx_dt
			)
		group by bene_id, indexdate
		having adrd_wang_s6=1
		order by bene_id, indexdate;
	quit;
%mend;
%s5_6()



/* MERGE OUTCOMES - DEFINE FINAL OUTCOME VARIABLE*/	
	/* Final Outcome Variable = Scenario 1B (2 ADRD dx claims within 1-year) 
							 OR Scenario 5 (1 ADRD dx with new rx within +/-90-days ) */

data out.adrd_wang_&drugA.v&drugB;
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

