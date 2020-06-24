extensions [stats]

Breed [Companies Company]
Breed [Inspectors Inspector]
undirected-link-breed [inspector_company_links inspector_company_link]

globals [
reputation_inspectors
inspectors_without_next_year_checkup
time

;;Data
data_estimated_correlation_a
data_estimated_correlation_b
data_estimated_correlation_c
data_estimated_correlation_d
data_estimated_correlation_e
estimated_correlation_list

;;Statistics
percentage_compliance_inspected
mean_percentage_compliance_inspected
sum_percentage_compliance_inspected
percentage_malpractice_inspected
mean_percentage_malpractice_inspected
sum_percentage_malpractice_inspected
global_observed_compliance
perceived_compliance
abs_difference_compliance
data_quality
]

Companies-own [
  moved?
  propensity_to_violate
  characteristic_a
  characteristic_b
  characteristic_c
  characteristic_d
  characteristic_e
  characteristic_list
  estimated_chance_to_get_inspected
  strategy_this_year
  company_inspected_this_year?
  company_inspected_last_year?
  inspected_by
  number_of_received_fines
  number_of_inspections
  fined_this_year?
  not_inspected_counter
  data_estimated_propensity_to_violate
  data_estimated_chance_to_violate
  trust_years_built
  trusted?
  trusted_years
  inspected_compliance
  inspected_malpractice
  company_observed_compliance
  company_observed_malpractice
  normalised_company_malpractice
  estimated_ptv_deviation
]

Inspectors-own [
  assigned?
  number_of_given_fines
  caught_last_year
  caught_this_year
]

Inspector_company_links-own [
  reputation
  inspected_this_year?
]

To setup
  clear-all
  reset-ticks
  set time 1
  let x 0.5 * sqrt(2 * number_of_companies)
  set-patch-size 206.14 / x
  resize-world (- x) x (- x) x
  ask patches [set pcolor 35]
  set-default-shape companies "house"
  set-default-shape inspectors "person"
  create-companies Number_of_Companies [
  	set color blue
    set propensity_to_violate random 100
    set company_inspected_this_year? false
    set company_inspected_last_year? false
    set trusted? false
    set_characteristics
  ]
  create-inspectors Number_of_Inspectors [
    setxy random-pxcor random-pycor
  	set color black
    set caught_this_year nobody
   ; create-inspector_company_links-with companies [
    ;  set hidden? true
     ; set inspected_this_year? false
      ;set reputation 50
    ;]
  ]
  ask companies [
    set estimated_chance_to_get_inspected Number_of_Inspectors / Number_of_Companies
    set company_observed_compliance -1
    set company_observed_malpractice -1
  ]
  set_initial_correlation_estimation
  sort_ptv
end

to set_characteristics
  ask companies [
    set characteristic_a correlation_a * propensity_to_violate + (1 - correlation_a) * random 200
    set characteristic_b correlation_b * propensity_to_violate + (1 - correlation_b) * random 200
    set characteristic_c correlation_c * propensity_to_violate + (1 - correlation_c) * random 200
    set characteristic_d correlation_d * propensity_to_violate + (1 - correlation_d) * random 200
    set characteristic_e correlation_e * propensity_to_violate + (1 - correlation_e) * random 200
  ]
end

to set_initial_correlation_estimation
  set data_estimated_correlation_a Initial_Correlation_Estimation_A
  set data_estimated_correlation_b Initial_Correlation_Estimation_B
  set data_estimated_correlation_c Initial_Correlation_Estimation_C
  set data_estimated_correlation_d Initial_Correlation_Estimation_D
  set data_estimated_correlation_e Initial_Correlation_Estimation_E
  set estimated_correlation_list (list data_estimated_correlation_a data_estimated_correlation_b data_estimated_correlation_c data_estimated_correlation_d data_estimated_correlation_e)
end

to sort_ptv
  ask companies [setxy max-pxcor min-pycor]
  ask patch min-pxcor max-pxcor [move_company]
end

to move_company ;function entered by patches calling companies
  if not any? companies-here and any? companies with [moved? != true] [
      ask max-one-of companies with [moved? != true] [propensity_to_violate] [
        move-to myself
        set moved? true
    ]
    ifelse pxcor + 2 <= max-pxcor [
      ask patch-at 2 0 [move_company]
    ][
      ask patch-at ((- max-pxcor * 2) + 1) -1 [move_company]
    ]
  ]
end

To go
  reset_yearly_variables
  companies_estimate_inspection_chance
  companies_set_strategy
  inspectors_select_companies
  perform_inspections
  update_data_estimated_correlations
  update_statistics
  tick
end

to reset_yearly_variables
  ask companies [
    set company_inspected_last_year? false
  ]
  ask companies with [company_inspected_this_year? = true] [
    set company_inspected_this_year? false
    set inspected_by false
    set company_inspected_last_year? true
  ]
  ask inspector_company_links with [inspected_this_year? = true] [
    set inspected_this_year? false
  ]
  ask inspectors [
    set assigned? false
    set caught_last_year caught_this_year
    set caught_this_year nobody
  ]
end

to companies_estimate_inspection_chance
  ask companies [
    ;;increase inspection estimation of company after they got caught
    if fined_this_year? = true [
      if estimated_chance_to_get_inspected < number_of_inspectors / number_of_companies [
        set estimated_chance_to_get_inspected (number_of_inspectors / number_of_companies)
      ]
      set estimated_chance_to_get_inspected min (list (estimated_chance_to_get_inspected * expected_inspection_multiplier_after_caught) 1)
      set fined_this_year? false
    ]
    ;;Reduces inspection estimation back to normal after not getting inspected
    if estimated_chance_to_get_inspected > (Number_of_inspectors / Number_of_companies) and company_inspected_last_year? = false [
      set estimated_chance_to_get_inspected (estimated_chance_to_get_inspected - (((Number_of_inspectors / Number_of_companies) * expected_inspection_multiplier_after_caught) - (Number_of_inspectors / Number_of_companies)) / time_to_reset_inspection_expectation_after_caught) ;; Estimated chance to get inspected from 100 back to normal in equal steps
      if estimated_chance_to_get_inspected < (Number_of_inspectors / Number_of_companies)[
        set estimated_chance_to_get_inspected (Number_of_inspectors / Number_of_companies) ;;Rounding
      ]
    ]
    ;;Reducing inspection estimation if company does not get inspected for at least 2 years in a row after its normal expectations have been reset
    if estimated_chance_to_get_inspected <= (number_of_inspectors / number_of_companies) and  not_inspected_counter >  0 [
      set estimated_chance_to_get_inspected max  (list (estimated_chance_to_get_inspected / (1 + percentage_expectation_decrease) ) (minimum_percentage_average_expectation / 100 *  (number_of_inspectors / number_of_companies)))
    ]
  ]
end

to companies_set_strategy
  ;; propensity to violate = 0 - 50 -> always comply
  ;; propensity to violate = 50 - 100 -> stop complying as soon as estimated profit is higher when not complying
  ;; propensity to violate = 50 -> stop complying as soon as estimated profit is twice as high when not complying
  ask companies [
    ifelse propensity_to_violate > Percentage_always_comply [
      ifelse (Fine * estimated_chance_to_get_inspected) / Costs_of_Compliance < propensity_to_violate / 100 [
        set strategy_this_year "don't comply"
        set color red
      ][
        set strategy_this_year "comply"
        set color green
    ]][;;else
      set strategy_this_year "comply"
      set color green
    ]
  ]
end

to inspectors_select_companies
  estimate_propensity_to_violate
  ;set_trusted_companies
  inspect_next_year_checkup
  inspect_data
  inspect_reputation_based
  inspect_random
end

to estimate_propensity_to_violate
  ;;Estimates the propensity to violate of companies based on their characteristics and the estimated correlation factors.
  ;;Can be adapted if not all characteristics are known -> change lists but be careful right now lists need to have the same length (same keys on the same indeces)
  ask companies [
    ifelse max estimated_correlation_list > 0 [  ;; else ?? wel nog de andere helft van deze functie doen toch?
    let new_estimated_correlation_list estimated_correlation_list
    let correlation_counter 0
    let new_characteristic_list (list characteristic_a characteristic_b characteristic_c characteristic_d characteristic_e)
    let estimated_ptv 0
    let break? false

    while [break? = false and length new_estimated_correlation_list > 0 and max new_estimated_correlation_list > 0] [
      let highest_correlation max new_estimated_correlation_list
    set correlation_counter correlation_counter + highest_correlation
    let characteristic_number position highest_correlation new_estimated_correlation_list
    set new_estimated_correlation_list remove-item characteristic_number new_estimated_correlation_list
    set estimated_ptv estimated_ptv + (item characteristic_number new_characteristic_list * highest_correlation)
    set new_characteristic_list remove-item characteristic_number new_characteristic_list
    if correlation_counter >= 1 [
          set break? true
      ]
    ]
    set data_estimated_propensity_to_violate (estimated_ptv / correlation_counter)
      ]
    [
      set data_estimated_propensity_to_violate random 100
    ]
   if max [company_observed_malpractice] of companies > 0 [

      ifelse company_observed_malpractice > -1 [
        set normalised_company_malpractice  (((company_observed_malpractice) / max [company_observed_malpractice] of companies)) * (max [data_estimated_propensity_to_violate] of companies)]
      [ifelse any? companies with [company_observed_malpractice > -1 and company_inspected_last_year? = true] [
        set normalised_company_malpractice ((mean [company_observed_malpractice] of companies with [company_observed_malpractice > -1 and company_inspected_last_year? = true]) / max [company_observed_malpractice] of companies) * (max [data_estimated_propensity_to_violate] of companies)]
        [ set normalised_company_malpractice 0 ]]
  ]
  set data_estimated_chance_to_violate data_estimated_propensity_to_violate + (Compliance_data_weight * normalised_company_malpractice)
  ]
end

to set_trusted_companies
  ask companies [
  if trust_years_built >= number_of_inspections_to_build_trust [
      set trust_years_built 0
      set trusted? true
    ]
    if any? companies with [company_observed_malpractice > 0 and company_inspected_last_year? = true] [
    if trusted? = true and normalised_company_malpractice > ((mean [company_observed_malpractice] of companies with [company_observed_malpractice > -1 and company_inspected_last_year? = true]) / max [company_observed_malpractice] of companies) * (max [data_estimated_propensity_to_violate] of companies) [
      set company_observed_compliance -1
      set company_observed_malpractice -1
  ]]]
;  ask companies [
;    if trust_years_built >= number_of_inspections_to_build_trust [
;      set trusted? true
;      set trust_years_built 0
;    ]
;    if trusted? = true [
;      set trusted_years trusted_years + 1
;    ]
;    if trusted_years > number_of_inspection_free_years_for_trusted_companies [
;      set trusted? false
;      set trusted_years 0
;    ]
;  ]
end

to inspect_next_year_checkup
  ask n-of ((percentage_next_year_checkup / 100) * number_of_inspectors) inspectors with [caught_last_year != nobody] [
    ask caught_last_year [get_inspected]
  ]
  set inspectors_without_next_year_checkup count inspectors with [assigned? = false]
end

to inspect_data
  ask n-of (round (inspectors_without_next_year_checkup / 100 * Percentage_Data)) inspectors with [assigned? = false] [
    if any? companies with [company_inspected_this_year? = false][
      ask max-one-of companies with [company_inspected_this_year? = false] [data_estimated_chance_to_violate]
      [get_inspected]
    ]
  ]
end

to inspect_random
  ;;rest of inspectors get assigned to a random company
  ask inspectors with [assigned? = false] [
    if any? companies with [company_inspected_this_year? = false][
      ask one-of companies with [company_inspected_this_year? = false]
        [get_inspected]
    ]
  ]
end

to inspect_reputation_based
  ask n-of round  (inspectors_without_next_year_checkup / 100 * Percentage_Reputation) inspectors with [assigned? = false] [
    if any? companies with [company_inspected_this_year? = false][
      ask [other-end] of min-one-of my-inspector_company_links with [[company_inspected_this_year?] of other-end = false ] [reputation]
        [get_inspected]
    ]
  ]
end

to get_inspected ;;Function a company enters when it gets inspected, asked by the Inspector
  set company_inspected_this_year? true
  set not_inspected_counter 0
  set inspected_by myself
  ask my-inspector_company_links with [other-end = [inspected_by] of myself]
    [set inspected_this_year? true]
  ask myself [
    set assigned? true
    move-to myself
  ]

end

to perform_inspections ;here fines are given, reputation scores are updated
  ask inspectors[
    if any? companies with [inspected_by = myself][
      ask companies with [inspected_by = myself][
        set number_of_inspections number_of_inspections + 1

        ;;Company gets inspecte while not compliant
        ifelse strategy_this_year = "don't comply" [
          set number_of_received_fines number_of_received_fines + 1
          set fined_this_year? true
          set trust_years_built 0
          set trusted? false
          set inspected_malpractice inspected_malpractice + 1
          ask myself [
            set number_of_given_fines number_of_given_fines + 1
            set caught_this_year myself
           ; ask inspector_company_link-with myself[
            ;  set reputation max (list (reputation - reputation_lost_when_caught) 0)]
          ]
        ][;;Company gets inspected while being compliant
          set trust_years_built trust_years_built + 1
          set inspected_compliance inspected_compliance + 1
          ;ask myself [
           ; ask inspector_company_link-with myself [
             ; if reputation <= 100 [
            ;    set reputation min (list (reputation + reputation_gained_when_compliance_inspected) 100 )
           ;   ]
          ;  ]
         ; ]
        ]
      ]
    ]
  ]
end
to update_data_estimated_correlations
  let data [(list characteristic_a propensity_to_violate)] of companies with [company_inspected_this_year? = true]
  let tbl stats:newtable-from-row-list data
  let cor-list stats:correlation tbl
  set data_estimated_correlation_a item 0 item 1 cor-list

  set data [(list characteristic_b propensity_to_violate)] of companies with [company_inspected_this_year? = true]
  set tbl stats:newtable-from-row-list data
  set cor-list stats:correlation tbl
  set data_estimated_correlation_b item 0 item 1 cor-list

  set data [(list characteristic_c propensity_to_violate)] of companies with [company_inspected_this_year? = true]
  set tbl stats:newtable-from-row-list data
  set cor-list stats:correlation tbl
  set data_estimated_correlation_c item 0 item 1 cor-list

  set data [(list characteristic_d propensity_to_violate)] of companies with [company_inspected_this_year? = true]
  set tbl stats:newtable-from-row-list data
  set cor-list stats:correlation tbl
  set data_estimated_correlation_d item 0 item 1 cor-list

  set data [(list characteristic_e propensity_to_violate)] of companies with [company_inspected_this_year? = true]
  set tbl stats:newtable-from-row-list data
  set cor-list stats:correlation tbl
  set data_estimated_correlation_e item 0 item 1 cor-list

  set estimated_correlation_list (list (max list 0 data_estimated_correlation_a) (max list 0 data_estimated_correlation_b) (max list 0 data_estimated_correlation_c) (max list 0 data_estimated_correlation_d) (max list 0 data_estimated_correlation_e))
end

to update_statistics
  set time time + 1
  set percentage_compliance_inspected (count Companies with [strategy_this_year = "comply" and company_inspected_this_year? = true] / max ( list 0.0001 (count companies with [strategy_this_year = "comply"]))) * 100
  set sum_percentage_compliance_inspected sum_percentage_compliance_inspected + percentage_compliance_inspected

  set percentage_malpractice_inspected (count Companies with [strategy_this_year = "don't comply" and company_inspected_this_year? = true] / max ( list 0.0001 (count companies with [strategy_this_year = "don't comply"]))) * 100
  set sum_percentage_malpractice_inspected sum_percentage_malpractice_inspected + percentage_malpractice_inspected

  set global_observed_compliance ((count Companies with [strategy_this_year = "comply"]) / (count companies )) * 100
  set perceived_compliance ((count Companies with [strategy_this_year = "comply" and company_inspected_this_year? = true])
/ (count companies with [company_inspected_this_year? = true] )) * 100
  set abs_difference_compliance abs(global_observed_compliance - perceived_compliance)

  if ticks > 0 [
    set mean_percentage_compliance_inspected sum_percentage_compliance_inspected / ticks
    set mean_percentage_malpractice_inspected sum_percentage_malpractice_inspected / ticks
  ]

  ask companies [
    set estimated_ptv_deviation abs (propensity_to_violate - data_estimated_propensity_to_violate)
    if number_of_inspections > 0 [set company_observed_compliance (inspected_compliance / number_of_inspections) * 100]
    if number_of_inspections > 0 [ set company_observed_malpractice (100 - company_observed_compliance) ]
   ; if not_inspected_counter > 9 and data_estimated_propensity_to_violate > mean [data_estimated_propensity_to_violate] of companies [set company_observed_compliance -1] ; hier moet iets natuurlijks komen waar
    if company_inspected_this_year? = false [
      set not_inspected_counter not_inspected_counter + 1

      if any? companies with [company_observed_malpractice > 0 and company_inspected_last_year? = true] [
      if not_inspected_counter > memory_compliance_years and normalised_company_malpractice < ((mean [company_observed_malpractice] of companies with [company_observed_malpractice > -1 and company_inspected_last_year? = true]) / max [company_observed_malpractice] of companies) * (max [data_estimated_propensity_to_violate] of companies) [
        set company_observed_compliance -1
        set company_observed_malpractice -1
        ]
      ]

      ask my-inspector_company_links [
        ifelse reputation <= 50 - reputation_forgotten_per_tick or reputation >= reputation + reputation_forgotten_per_tick [
        ifelse reputation > 50 [
          set reputation reputation - reputation_forgotten_per_tick
        ][
          set reputation reputation + reputation_forgotten_per_tick
        ]
        ][
          set reputation 50 ;reset reputation to 50 if it is within range
        ]
      ]
    ]
  ]
  set_trusted_companies

  set data_quality
5  - ( abs (correlation_a - data_estimated_correlation_a) +
abs (correlation_b - data_estimated_correlation_b) +
abs (correlation_c - data_estimated_correlation_c) +
abs (correlation_d - data_estimated_correlation_d) +
      abs (correlation_e - data_estimated_correlation_e))

end


to correlate
  let data [(list characteristic_a propensity_to_violate)] of companies with [company_inspected_this_year? = true]

  let tbl stats:newtable-from-row-list data

  let cor-list stats:correlation tbl

  print item 0 item 1 cor-list
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
613
414
-1
-1
18.817921334019157
1
10
1
1
1
0
0
0
1
-10
10
-10
10
0
0
1
ticks
30.0

BUTTON
27
10
91
43
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
26
44
106
77
Go-Once
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
26
79
89
112
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
6
121
181
154
Number_of_Companies
Number_of_Companies
1
500
240.0
1
1
NIL
HORIZONTAL

SLIDER
5
153
180
186
Number_of_Inspectors
Number_of_Inspectors
2
100
40.0
1
1
NIL
HORIZONTAL

MONITOR
659
326
797
371
Number of Fines Given
sum [number_of_given_fines] of inspectors
17
1
11

SLIDER
1606
216
1820
249
Percentage_Reputation
Percentage_Reputation
0
100
0.0
1
1
NIL
HORIZONTAL

MONITOR
26
284
151
329
Percentage Random
100 - Percentage_Reputation - Percentage_Data
17
1
11

PLOT
938
385
1217
606
Percentage of Malpractice Inspected
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if ticks > 0 [\n\nplot ((count Companies with [strategy_this_year = \"don't comply\" and company_inspected_this_year? = true])\n/ (count companies with [strategy_this_year = \"don't comply\"])) * 100]"

PLOT
649
386
936
607
% Inspections at Propensity to Violate > 75
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if ticks > 0 [\n\nplot ((count Companies with [propensity_to_violate > 75 and company_inspected_this_year? = true])\n/ (count companies with [propensity_to_violate > 75])) * 100]"

MONITOR
797
280
1031
325
Mean Percentage Compliance Inspected
mean_percentage_compliance_inspected
4
1
11

MONITOR
799
326
1033
371
Mean Percentage Malpractice Inspected
mean_percentage_malpractice_inspected
17
1
11

MONITOR
659
280
796
325
Percentage Malpractice
count companies with [strategy_this_year = \"don't comply\"] / count companies * 100
17
1
11

SLIDER
9
672
315
705
time_to_reset_inspection_expectation_after_caught
time_to_reset_inspection_expectation_after_caught
0
10
5.0
1
1
ticks
HORIZONTAL

SLIDER
1603
117
1819
150
reputation_lost_when_caught
reputation_lost_when_caught
0
100
24.0
1
1
NIL
HORIZONTAL

SLIDER
1603
149
1820
182
reputation_gained_when_compliance_inspected
reputation_gained_when_compliance_inspected
0
100
11.0
1
1
NIL
HORIZONTAL

SLIDER
1605
183
1823
216
reputation_forgotten_per_tick
reputation_forgotten_per_tick
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
5
217
181
250
Costs_of_Compliance
Costs_of_Compliance
1
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
5
185
180
218
Fine
Fine
0
500
120.0
1
1
NIL
HORIZONTAL

SLIDER
9
437
181
470
Correlation_A
Correlation_A
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
9
468
181
501
Correlation_B
Correlation_B
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
9
500
181
533
Correlation_C
Correlation_C
0
1
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
9
531
181
564
Correlation_D
Correlation_D
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
9
562
181
595
Correlation_E
Correlation_E
0
1
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
10
704
316
737
percentage_next_year_checkup
percentage_next_year_checkup
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
6
249
182
282
Percentage_Data
Percentage_Data
0
100
90.0
1
1
NIL
HORIZONTAL

SLIDER
180
437
404
470
Initial_Correlation_Estimation_A
Initial_Correlation_Estimation_A
0
1
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
179
468
404
501
Initial_Correlation_Estimation_B
Initial_Correlation_Estimation_B
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
179
501
403
534
Initial_Correlation_Estimation_C
Initial_Correlation_Estimation_C
0
1
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
179
532
403
565
Initial_Correlation_Estimation_D
Initial_Correlation_Estimation_D
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
179
562
404
595
Initial_Correlation_Estimation_E
Initial_Correlation_Estimation_E
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
10
640
315
673
expected_inspection_multiplier_after_caught
expected_inspection_multiplier_after_caught
1
5
1.2
0.1
1
NIL
HORIZONTAL

SLIDER
9
736
316
769
number_of_inspections_to_build_trust
number_of_inspections_to_build_trust
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
1554
248
1863
281
number_of_inspection_free_years_for_trusted_companies
number_of_inspection_free_years_for_trusted_companies
0
10
10.0
1
1
NIL
HORIZONTAL

PLOT
659
11
934
279
Compliance vs Observed Compliance
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "if ticks > 1 [\n\nplot ((count Companies with [strategy_this_year = \"comply\" and company_inspected_this_year? = true])\n/ (count companies with [company_inspected_this_year? = true] )) * 100]"
"pen-1" 1.0 0 -7500403 true "" "if ticks > 1 [\n\nplot ((count Companies with [strategy_this_year = \"comply\"])\n/ (count companies )) * 100]"

BUTTON
1631
31
1712
64
NIL
correlate
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
935
10
1254
280
Data Correlation Deviation
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot 5 - ( abs (correlation_a - data_estimated_correlation_a) +\nabs (correlation_b - data_estimated_correlation_b) +\nabs (correlation_c - data_estimated_correlation_c) +\nabs (correlation_d - data_estimated_correlation_d) +\nabs (correlation_e - data_estimated_correlation_e))"

BUTTON
1632
62
1711
95
NIL
sort_ptv
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
401
198
434
Compliance_data_weight
Compliance_data_weight
0
5
3.0
0.1
1
NIL
HORIZONTAL

PLOT
1256
10
1539
280
estimated_ptv_deviation
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [estimated_ptv_deviation] of companies"

SLIDER
9
767
319
800
memory_compliance_years
memory_compliance_years
0
10
5.0
1
1
NIL
HORIZONTAL

PLOT
1217
384
1481
605
Percentage Compliance
NIL
NIL
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count companies with [strategy_this_year = \"comply\"] / count companies * 100"

SLIDER
7
331
210
364
Percentage_always_comply
Percentage_always_comply
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
802
682
1094
715
minimum_percentage_average_expectation
minimum_percentage_average_expectation
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
825
720
1073
753
percentage_expectation_decrease
percentage_expectation_decrease
0
1
0.02
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Correlation_A">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Correlation_B">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_inspections_to_build_trust">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Correlation_C">
      <value value="0.6"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Costs_of_Compliance" first="1" step="20" last="70"/>
    <enumeratedValueSet variable="memory_compliance_years">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percentage_expectation_decrease">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="expected_inspection_multiplier_after_caught">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial_Correlation_Estimation_E">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_inspection_free_years_for_trusted_companies">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Number_of_Inspectors" first="5" step="10" last="50"/>
    <steppedValueSet variable="Percentage_always_comply" first="30" step="20" last="70"/>
    <enumeratedValueSet variable="percentage_next_year_checkup">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial_Correlation_Estimation_A">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial_Correlation_Estimation_B">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time_to_reset_inspection_expectation_after_caught">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Compliance_data_weight">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial_Correlation_Estimation_C">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_percentage_average_expectation">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage_Data">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Initial_Correlation_Estimation_D">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage_Reputation">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Fine" first="1" step="50" last="350"/>
    <steppedValueSet variable="Number_of_Companies" first="5" step="30" last="300"/>
    <enumeratedValueSet variable="reputation_forgotten_per_tick">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reputation_gained_when_compliance_inspected">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Correlation_D">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reputation_lost_when_caught">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Correlation_E">
      <value value="0.6"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
