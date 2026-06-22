CACHE_IDXW ?= 7
JOBS ?= 2
SBY ?= sby
SBY_CONFIG := cache_verify.sby
GENERATED_DIR := generated
RTL_DIR := $(GENERATED_DIR)/rtl
SBY_DIR := $(GENERATED_DIR)/sby
SBY_PREFIX := $(SBY_DIR)/cache_verify
REPORT_FILE := $(GENERATED_DIR)/REPORT.md
REPORT_SCRIPT := scripts/cache_formal_report.py
PYTHON ?= python3
CONTROL_TASKS := icache_invalid dcache_clean dcache_invalid icache_invalid_refetch dcache_invalid_refetch dcache_clean_writeback dcache_clean_twice
SANITY_TASKS := icache_invalid_sanity dcache_clean_sanity dcache_invalid_sanity icache_invalid_refetch_sanity dcache_invalid_refetch_sanity dcache_clean_writeback_sanity dcache_clean_twice_sanity

.PHONY: all full rtl prove cover control sanity status report clean

all: prove cover

full: prove control sanity cover

rtl:
	$(MAKE) -C ../CL1_Core verilog-cache-formal CL1_CACHE_IDXW=$(CACHE_IDXW)
	mkdir -p $(RTL_DIR)
	rm -f $(RTL_DIR)/Cl1Cache*.sv
	cp ../CL1_Core/vsrc/Cl1CacheFormal.sv $(RTL_DIR)/Cl1CacheFormal.sv

prove: rtl
	mkdir -p $(SBY_DIR)
	$(SBY) -j $(JOBS) --sequential -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cache
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --write $(REPORT_FILE)

cover: rtl
	mkdir -p $(SBY_DIR)
	$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cover
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --write $(REPORT_FILE)

control: rtl
	mkdir -p $(SBY_DIR)
	$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(CONTROL_TASKS)
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --write $(REPORT_FILE)

sanity: rtl
	mkdir -p $(SBY_DIR)
	$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(SANITY_TASKS)
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --write $(REPORT_FILE)

status:
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --status

report:
	mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(REPORT_SCRIPT) --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --write $(REPORT_FILE)

clean:
	rm -rf $(GENERATED_DIR) rtl cache_verify cache_verify_* cache_verify.generated* cache_verify.full_induct.tmp* *.tmp.sby
