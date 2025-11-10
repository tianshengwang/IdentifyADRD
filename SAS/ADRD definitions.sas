/***********************************************************************************************************/
/* Program: ADRD_definitions.sas                                                                           */
/* Purpose: ICD code or drugs for ADRD algorithms                                                          */
/***********************************************************************************************************/


options sasautos=(SASAUTOS "M:\cvd_associates_projects\aric_ms2948\programs\macros");
%setup(programName=ADRD definitions, saveLog=N)


/*2/15/2022: Tian added the folloing macro developed by Virginia to add a new variable: hypothyroidism */
%macro dx(name, dx9list, dx10list);
 
   %LET N9 = %SYSFUNC(countw(&dx9list,','));
   %DO i=1 %TO &N9;
      %LET code9_&i = %SYSFUNC(compress(%SCAN(&dx9list, &i, ','),.));
   %END;
 
   %LET newdx9list = ;
   %DO i=1 %TO &N9; %LET newdx9list = &newdx9list "&&code9_&i"; %END;
 
   %LET N10 = %SYSFUNC(countw(&dx10list,','));
   %DO i=1 %TO &N10;
      %LET code10_&i = %SYSFUNC(compress(%SCAN(&dx10list, &i, ','),.));
   %END;
 
   %LET newdx10list = ;
   %DO i=1 %TO &N10; %LET newdx10list = &newdx10list "&&code10_&i"; %END;
 
 
   data covref.&name._icd9dx; set dx.dx(keep=code label);
      where code in: (&newdx9List); run;
 
   data covref.&name._icd10dx(rename=(short_description=label)); set dx10.dx10(keep=code short_description);
      where code in: (&newdx10List); run;
%mend;


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

data adrdref.bynum_adrd_icd10dx;*From forward/backward mapping - G31.9 not included; 
*12/2/2024 - NOTE - Bynum ICD10 published algorithm is available, but we did not see it at the time - should we ue the published code list or this list?;
	set dx10.dx10(rename=(short_description=description));
	where code in: ('G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181'
					 'G3101' 'G3109' 'G311' 'G3183' 'G3189' 'G138' 'G94' 'F068');

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
	if code ^in: ('29011' '2903' '29041' '2940') then wang_primary=1; else wang_primary=0;

	keep code description wang wang_secondary wang_primary;
run;


data adrdref.wang_adrd_icd10dx;
	set dx10.dx10(rename=(short_description=description));
	where code in: ('G300' 'G301' 'G308' 'G309' 'F0150' 'F0151' 'F0280' 'F0281' 'F0390' 'F0391' 'F04' 'R4181'
					'G3101' 'G3109' 'G311' 'G3183');

	wang=1; wang_primary=1; wang_secondary=0; 
	keep code description wang wang_primary wang_secondary;
run;




/* FDA approved drugs for ADRD: 4 symptomatic treatments (donepezil, rivastigmine, galantamine, memantine)*/
/* and two AD-specific agents that slow progression (aducanumab and lecanemab). */


%macro getndc(class, atc);
   proc sort data=&class._name; by drugName; run;
   proc sql noprint; 
      select distinct drugName into :drug1-:drug100 from &class._name;
      %LET NumDrug = &SqlObs; 

      select distinct atc into :atc1-:atc100 from &class._name;
      %LET NumATC = &SqlObs;
   quit;

   proc sql;
      create table adrdref.&class._ndc(where=(ndc11 ne '')) as
      select case when a.drugName ne '' then a.drugName 
         %DO i=1 %TO &numDrug; 
            when index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") then "&&drug&i"
         %END; end as drug, b.*
      from &class._name as a 
       full join atc.atc_ndc(where=(%IF &atc ne  %THEN atc in: (&atc) or;
           %DO i=1 %TO &numDrug; 
                index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") or %END;
           %IF &numATC > 0 %THEN %DO; %DO i=1 %TO &numATC;
                 atc=:"&&atc&i" %IF &i<&numATC %THEN or ; %END; %END;)) as b
       on a.atc = b.atc
       order by drug, ndc11;
   quit;
%mend;
libname atc 'M:\cvd_associates_projects\aric_ms2948\reference\Code Reference Sets\Drugs';

*TACRINE AND IPIDACRINE NOT INCLUDED IN DEFINITION - CHECK TO SEE IF THERE ARE CLAIMS FOR THESE DRUGS;
data ADRD_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
   DONEPEZIL N06DA02
   DONEPEZIL N06DA52
   DONEPEZIL N06DA53
   RIVASTIGMINE N06DA03
   GALANTAMINE N06DA04
   MEMANTINE N06DA52
   MEMANTINE N06DA53
   MEMANTINE N06DX01
   TACRINE N06DA01
   IPIDACRINE N06DA05
   ;
run;
%getndc(class=adrd, atc=%STR('N06DA'))

*NO ATC CODE FOR lecanemab (NOT APPROVED UNTIL 2023 SO WILL NOT BE IN OUR DATA) OR aducanumab (APPROVED 2021);


data ad_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
   ADUCANUMAB N06DX03
   ;
run;
%getndc(class=ad, atc=%STR('N06DX03'))


