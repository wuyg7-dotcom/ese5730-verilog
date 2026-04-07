setMultiCpuUsage -localCpu 8

create_ccopt_clock_tree_spec

get_ccopt_clock_trees *

set_ccopt_property target_max_trans 0.75
set_ccopt_property target_skew 0.25

set_db cts_buffer_cells "buf_1 buf_2 buf_4 buf_8 buf_16"
set_db cts_inverter_cells "inv_1 inv_2 inv_4 inv_8 inv_16"

set_db cts_use_inverters true
#set_db route_design_detail_use_multi_cut_via_effort high

clock_opt_design
