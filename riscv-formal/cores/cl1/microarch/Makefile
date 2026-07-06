.PHONY: run all all-fast csr csr-unit csr-exec csr-trap-scenarios csr-trap-model if-stage idex-stage clean clean-csr

run: all-fast

all: if-stage idex-stage csr

all-fast: if-stage idex-stage csr-unit csr-trap-scenarios csr-trap-model

csr:
	$(MAKE) -C csr run

csr-unit:
	$(MAKE) -C csr unit

csr-exec:
	$(MAKE) -C csr exec

csr-trap-scenarios:
	$(MAKE) -C csr trap-scenarios

csr-trap-model:
	$(MAKE) -C csr trap-model

if-stage:
	$(MAKE) -C if_stage run

idex-stage:
	$(MAKE) -C idex_stage run

clean:
	$(MAKE) -C if_stage clean
	$(MAKE) -C idex_stage clean
	$(MAKE) -C csr clean

clean-csr:
	$(MAKE) -C csr clean
