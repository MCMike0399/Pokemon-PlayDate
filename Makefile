SDK = $(if $(PLAYDATE_SDK_PATH),$(PLAYDATE_SDK_PATH),$(HOME)/Developer/PlaydateSDK)
PDC = $(SDK)/bin/pdc
PDUTIL = $(SDK)/bin/pdutil
PRODUCT = PokemonPoC.pdx
DEVICE = $(shell python3 -c 'from tools.harness.run import playdate_serial_ports; ports = playdate_serial_ports(); print(ports[0] if ports else "")')

build: compile
	$(MAKE) run

clean:
	rm -rf $(PRODUCT)

compile:
	python3 tools/build.py --sdk "$(SDK)" --output "$(PRODUCT)"

run:
	@if [ -x "$(SDK)/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" ]; then \
		open -a "$(SDK)/bin/Playdate Simulator.app" $(PRODUCT); \
	elif [ -x "$(SDK)/bin/PlaydateSimulator" ]; then \
		"$(SDK)/bin/PlaydateSimulator" $(PRODUCT); \
	else \
		echo "Playdate Simulator executable not found under $(SDK)/bin"; \
		exit 1; \
	fi

# Deploy to physical Playdate: build, enter data disk, copy, eject & reboot
deploy: compile
	@DEVICE=$$(python3 -c 'from tools.harness.run import playdate_serial_ports; ports = playdate_serial_ports(); print(ports[0] if ports else "")'); \
	if [ -z "$$DEVICE" ]; then \
		echo "Error: No Playdate serial node found. Connect via USB and unlock the device."; \
		exit 1; \
	fi; \
	echo "Putting Playdate into Data Disk mode..."; \
	$(PDUTIL) $$DEVICE datadisk; \
	echo "Waiting for PLAYDATE volume to mount..."; \
	TRIES=0; \
	VOLUME=""; \
	while [ $$TRIES -lt 90 ]; do \
		VOLUME=$$(python3 -c 'from tools.harness.run import playdate_data_volume; volume = playdate_data_volume(); print(volume or "")'); \
		if [ -n "$$VOLUME" ] && [ -d "$$VOLUME/Games" ]; then \
			break; \
		fi; \
		sleep 1; \
		TRIES=$$((TRIES + 1)); \
	done; \
	if [ -z "$$VOLUME" ] || [ ! -d "$$VOLUME/Games" ]; then \
		echo "Error: PLAYDATE volume did not mount after 90s."; \
		exit 1; \
	fi; \
	echo "Copying $(PRODUCT) to Playdate..."; \
	rm -rf "$$VOLUME/Games/$(PRODUCT)"; \
	cp -R $(PRODUCT) "$$VOLUME/Games/"; \
	echo "Ejecting Playdate (will reboot)..."; \
	python3 -c 'from tools.harness.run import eject_argv; import subprocess, sys; from pathlib import Path; raise SystemExit(subprocess.call(eject_argv(Path(sys.argv[1]))))' "$$VOLUME"; \
	echo "Done! Playdate will reboot with $(PRODUCT) installed."

.PHONY: build clean compile run deploy harness-smoke test-harness
harness-smoke:
	python3 tools/harness/run.py --scenario tools/harness/smoke.json

test-harness:
	python3 -m unittest discover -s tools/tests -p 'test_protocol*.py' -v
