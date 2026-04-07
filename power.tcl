setMultiCpuUsage -localCpu 8

set_db init_ground_nets VSS
set_db init_power_nets VDD
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
