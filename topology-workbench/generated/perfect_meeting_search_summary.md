# Perfect Meeting Search Summary

Horizon policy: `all_pairs:fixed_Bmax_4;cross_polygon_pairs:fixed_Bmax_8`

- family `uniform_3_1` / pair universe `all_pairs` with alphabet `single_move` from `uniform_3_1_zero`: outcome=`Failure`, pair_count=15, missing=15, duplicates=0, searched_schedule_count=0, terminated=`exhausted_precheck_same_polygon_obstruction`
  obstruction: count_obstruction.same_polygon_pair_unrealizable: pair [0, 1] lies in one polygon; default all_pairs universe includes intra-polygon pairs while the frozen meeting law realizes only cross-polygon alignments; per_state_pairs=3, horizon_policy=fixed_Bmax_4
- family `uniform_3_1` / pair universe `cross_polygon_pairs` with alphabet `single_move` from `uniform_3_1_zero`: outcome=`Success`, pair_count=9, missing=0, duplicates=0, searched_schedule_count=2081, terminated=`found_success`
  witness_schedule: +e0, +e0, +e1, +e0, +e0, +e1, +e0, +e0
  schedule_id: 84eb35275c87927da1186421f4a3c80c0cde64aa657a1c4465a8e424f223754a
  execution_trace_digest: 7f65a25b6b0a73d55015f411f6081214000245c170a2965fee4d4fe2438b75b2
  obstruction: sanity_stage_nondegenerate: reachable_pair_union_size=9 over fixed_Bmax_8
- family `uniform_3_2` / pair universe `all_pairs` with alphabet `single_move` from `uniform_3_2_zero`: outcome=`Failure`, pair_count=36, missing=36, duplicates=0, searched_schedule_count=0, terminated=`exhausted_precheck_same_polygon_obstruction`
  obstruction: count_obstruction.same_polygon_pair_unrealizable: pair [0, 1] lies in one polygon; default all_pairs universe includes intra-polygon pairs while the frozen meeting law realizes only cross-polygon alignments; per_state_pairs=9, horizon_policy=fixed_Bmax_4
- family `uniform_3_2` / pair universe `cross_polygon_pairs` with alphabet `single_move` from `uniform_3_2_zero`: outcome=`Failure`, pair_count=27, missing=24, duplicates=1, searched_schedule_count=0, terminated=`analytic_obstruction_single_move_preserves_one_cross_pair_each_step`
  witness_schedule: +e0
  schedule_id: c8e71957645a4073563db18cc93d4278537d7679fba4ba212d7495f133c9f470
  search_trace_digest: b51a05ae92c213747403ab1bfcaf4f3c72be345a5faa2a4fbb58eb8e84586633
  obstruction: analytic_obstruction: with cross-polygon realization on uniform_3_2, each single-move step changes only one coordinate, leaving one pair type unchanged from the previous state; therefore a duplicate pair appears at t=1 for any first move, so exact-once is impossible.
