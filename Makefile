SHELL := /bin/bash

.DEFAULT_GOAL := help

VCS   ?= vcs
VERDI ?= verdi

VCS_FLAGS := -full64 -sverilog -kdb -debug_access+all \
	-timescale=1ns/1ps +define+ENABLE_FSDB

AXIS_FIFO_DIR  := vcs_build/axis_fifo_tb
AXIS_FSM_DIR   := vcs_build/axis_fifo_fsm_tb
AXI_CSR_DIR    := vcs_build/axi_lite_csr_tb
AXI_CSR_SCENARIO ?= aw_first
AXI_CSR_FSDB := $(AXI_CSR_DIR)/$(AXI_CSR_SCENARIO).fsdb
AXI_CSR_SIM_LOG := $(AXI_CSR_DIR)/$(AXI_CSR_SCENARIO).sim.log

.PHONY: help \
	axis_fifo axis_fifo_compile axis_fifo_sim axis_fifo_verdi \
	axis_fifo_fsm axis_fifo_fsm_compile axis_fifo_fsm_sim axis_fifo_fsm_verdi \
	axi_lite_csr axi_lite_csr_compile axi_lite_csr_sim axi_lite_csr_verdi

help:
	@echo "Available targets:"
	@echo "  make axis_fifo       Compile, simulate, and open axis_fifo_tb in Verdi"
	@echo "  make axis_fifo_fsm   Compile, simulate, and open axis_fifo_fsm_tb in Verdi"
	@echo "  make axi_lite_csr    Compile, simulate, and open axi_lite_csr_tb in Verdi"
	@echo "  make axi_lite_csr_sim AXI_CSR_SCENARIO=b_backpressure"
	@echo "  make axi_lite_csr_sim AXI_CSR_SCENARIO=read_status"
	@echo ""
	@echo "Each target also has _compile, _sim, and _verdi variants."

axis_fifo_compile:
	mkdir -p $(AXIS_FIFO_DIR)
	$(VCS) $(VCS_FLAGS) \
		-top axis_fifo_tb \
		-Mdir=$(AXIS_FIFO_DIR)/csrc \
		-o $(AXIS_FIFO_DIR)/simv \
		-l $(AXIS_FIFO_DIR)/compile.log \
		rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_tb.sv

axis_fifo_sim: axis_fifo_compile
	./$(AXIS_FIFO_DIR)/simv \
		+fsdbfile=$(AXIS_FIFO_DIR)/axis_fifo.fsdb \
		-l $(AXIS_FIFO_DIR)/sim.log

axis_fifo_verdi:
	$(VERDI) -kdb \
		-simdir $(AXIS_FIFO_DIR)/csrc \
		-ssf $(AXIS_FIFO_DIR)/axis_fifo.fsdb

axis_fifo: axis_fifo_sim
	$(VERDI) -kdb \
		-simdir $(AXIS_FIFO_DIR)/csrc \
		-ssf $(AXIS_FIFO_DIR)/axis_fifo.fsdb

axis_fifo_fsm_compile:
	mkdir -p $(AXIS_FSM_DIR)
	$(VCS) $(VCS_FLAGS) \
		-top axis_fifo_fsm_tb \
		-Mdir=$(AXIS_FSM_DIR)/csrc \
		-o $(AXIS_FSM_DIR)/simv \
		-l $(AXIS_FSM_DIR)/compile.log \
		rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_fsm_tb.sv

axis_fifo_fsm_sim: axis_fifo_fsm_compile
	./$(AXIS_FSM_DIR)/simv \
		+fsdbfile=$(AXIS_FSM_DIR)/axis_fifo_fsm.fsdb \
		-l $(AXIS_FSM_DIR)/sim.log

axis_fifo_fsm_verdi:
	$(VERDI) -kdb \
		-simdir $(AXIS_FSM_DIR)/csrc \
		-ssf $(AXIS_FSM_DIR)/axis_fifo_fsm.fsdb

axis_fifo_fsm: axis_fifo_fsm_sim
	$(VERDI) -kdb \
		-simdir $(AXIS_FSM_DIR)/csrc \
		-ssf $(AXIS_FSM_DIR)/axis_fifo_fsm.fsdb

axi_lite_csr_compile:
	mkdir -p $(AXI_CSR_DIR)
	$(VCS) $(VCS_FLAGS) \
		-top axi_lite_csr_tb \
		-Mdir=$(AXI_CSR_DIR)/csrc \
		-o $(AXI_CSR_DIR)/simv \
		-l $(AXI_CSR_DIR)/compile.log \
		rtl/csr/axi_lite_csr.sv verification/tb/axi_lite_csr_tb.sv

axi_lite_csr_sim: axi_lite_csr_compile
	./$(AXI_CSR_DIR)/simv \
		+scenario=$(AXI_CSR_SCENARIO) \
		+fsdbfile=$(AXI_CSR_FSDB) \
		-l $(AXI_CSR_SIM_LOG)

axi_lite_csr_verdi:
	$(VERDI) -kdb \
		-simdir $(AXI_CSR_DIR)/csrc \
		-ssf $(AXI_CSR_FSDB)

axi_lite_csr: axi_lite_csr_sim
	$(VERDI) -kdb \
		-simdir $(AXI_CSR_DIR)/csrc \
		-ssf $(AXI_CSR_FSDB)
