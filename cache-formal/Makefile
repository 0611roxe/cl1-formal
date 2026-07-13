CACHE_IDXW ?= 1
CACHE_FULL_IDXW ?= 7
JOBS ?= 2
SBY ?= sby
SBY_CONFIG := cache_verify.sby
GENERATED_DIR := generated
GEOMETRY_TAG := idxw$(CACHE_IDXW)
RTL_DIR := $(GENERATED_DIR)/rtl
RTL_SNAPSHOT_DIR := $(RTL_DIR)/$(GEOMETRY_TAG)
SBY_DIR := $(GENERATED_DIR)/sby/$(GEOMETRY_TAG)
SBY_PREFIX := $(SBY_DIR)/cache_verify
REPORT_FILE := $(GENERATED_DIR)/reports/$(GEOMETRY_TAG)/REPORT.md
REPORT_SCRIPT := scripts/cache_formal_report.py
REPORT_ARGS := --sby-dir $(SBY_DIR) --prefix cache_verify --sby-config $(SBY_CONFIG) --geometry $(GEOMETRY_TAG) --rtl $(RTL_SNAPSHOT_DIR)/Cl1CacheFormal.sv
PYTHON ?= python3
CONTROL_TASKS := icache_invalid dcache_clean dcache_invalid icache_invalid_refetch dcache_invalid_refetch dcache_clean_writeback dcache_clean_twice
SANITY_TASKS := icache_invalid_sanity dcache_clean_sanity dcache_invalid_sanity icache_invalid_refetch_sanity dcache_invalid_refetch_sanity dcache_clean_writeback_sanity dcache_clean_twice_sanity
TURNOVER_TASKS := turnover turnover_sanity
BACKPRESSURE_TASKS := backpressure backpressure_sanity
FULL_GEOMETRY_TASKS := cache_full $(CONTROL_TASKS) $(SANITY_TASKS)
QUICK_TASKS := cache cover
FULL_TASKS := $(QUICK_TASKS) $(TURNOVER_TASKS) $(BACKPRESSURE_TASKS) $(CONTROL_TASKS) $(SANITY_TASKS)

define RUN_SBY
@set +e; \
run_started=$$(date +%s); \
update_report() { $(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --stamp-tasks $(2) --stamp-after "$$run_started" --write $(REPORT_FILE); }; \
trap 'update_report >/dev/null 2>&1 || true' INT TERM; \
$(1); sby_rc=$$?; \
trap - INT TERM; \
update_report; report_rc=$$?; \
if [ "$$sby_rc" -ne 0 ]; then exit "$$sby_rc"; fi; \
exit "$$report_rc"
endef

.PHONY: all full full-geometry full-geometry-run full-geometry-safety full-geometry-control full-geometry-sanity rtl prove turnover backpressure prove-full-geometry prove-full-geometry-run cover control sanity status check-all check-full check-full-geometry report clean

all: prove cover
	$(MAKE) check-all

full: prove turnover backpressure control sanity cover
	$(MAKE) check-full

full-geometry:
	$(MAKE) CACHE_IDXW=$(CACHE_FULL_IDXW) full-geometry-run

full-geometry-run: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cache_full,cache_full)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(CONTROL_TASKS),$(CONTROL_TASKS))
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(SANITY_TASKS),$(SANITY_TASKS))
	$(MAKE) check-full-geometry

full-geometry-safety:
	$(MAKE) CACHE_IDXW=$(CACHE_FULL_IDXW) prove-full-geometry-run

full-geometry-control:
	$(MAKE) CACHE_IDXW=$(CACHE_FULL_IDXW) control

full-geometry-sanity:
	$(MAKE) CACHE_IDXW=$(CACHE_FULL_IDXW) sanity

rtl:
	$(MAKE) -C ../CL1_Core verilog-cache-formal CL1_CACHE_IDXW=$(CACHE_IDXW)
	mkdir -p $(RTL_DIR)
	rm -f $(RTL_DIR)/Cl1Cache*.sv
	cp ../CL1_Core/vsrc/Cl1CacheFormal.sv $(RTL_DIR)/Cl1CacheFormal.sv
	mkdir -p $(RTL_SNAPSHOT_DIR)
	rm -f $(RTL_SNAPSHOT_DIR)/Cl1Cache*.sv
	cp ../CL1_Core/vsrc/Cl1CacheFormal.sv $(RTL_SNAPSHOT_DIR)/Cl1CacheFormal.sv

prove: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) --sequential -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cache,cache)

turnover: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) --sequential -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(TURNOVER_TASKS),$(TURNOVER_TASKS))

backpressure: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) --sequential -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(BACKPRESSURE_TASKS),$(BACKPRESSURE_TASKS))

prove-full-geometry:
	$(MAKE) CACHE_IDXW=$(CACHE_FULL_IDXW) prove-full-geometry-run

prove-full-geometry-run: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cache_full,cache_full)

cover: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) cover,cover)

control: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(CONTROL_TASKS),$(CONTROL_TASKS))

sanity: rtl
	mkdir -p $(SBY_DIR)
	$(call RUN_SBY,$(SBY) -j $(JOBS) -f --prefix $(SBY_PREFIX) $(SBY_CONFIG) $(SANITY_TASKS),$(SANITY_TASKS))

status:
	$(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --status $(if $(REQUIRE_TASKS),--require-tasks $(REQUIRE_TASKS))

check-all:
	$(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --status --require-tasks $(QUICK_TASKS)

check-full:
	$(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --status --require-tasks $(FULL_TASKS)

check-full-geometry:
	$(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --status --require-tasks $(FULL_GEOMETRY_TASKS)

report:
	mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(REPORT_SCRIPT) $(REPORT_ARGS) --write $(REPORT_FILE)

clean:
	rm -rf $(GENERATED_DIR) rtl cache_verify cache_verify_* cache_verify.generated* cache_verify.full_induct.tmp* *.tmp.sby
