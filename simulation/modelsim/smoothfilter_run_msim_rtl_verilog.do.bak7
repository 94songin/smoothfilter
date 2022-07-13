transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/intelFPGA_lite/19.1/smooth_op {C:/intelFPGA_lite/19.1/smooth_op/smoothfilter.v}
vlog -vlog01compat -work work +incdir+C:/intelFPGA_lite/19.1/smooth_op {C:/intelFPGA_lite/19.1/smooth_op/sram.v}

vlog -vlog01compat -work work +incdir+C:/intelFPGA_lite/19.1/smooth_op {C:/intelFPGA_lite/19.1/smooth_op/tb_smoothfilter.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  tb_smoothfilter

add wave *
view structure
view signals
run -all
