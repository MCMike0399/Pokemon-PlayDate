SDK = $(PLAYDATE_SDK_PATH)
PDC = $(SDK)/bin/pdc
PDUTIL = $(SDK)/bin/pdutil
PRODUCT = PokemonPoC.pdx
DEVICE = $(shell ls /dev/cu.usbmodemPD* 2>/dev/null | head -1)

build: clean compile run

clean:
	rm -rf $(PRODUCT)

compile:
	$(PDC) Source $(PRODUCT)

run:
	open -a "$(SDK)/bin/Playdate Simulator.app" $(PRODUCT)

# Deploy to physical Playdate: build, enter data disk, copy, eject & reboot
deploy: clean compile
	@DEVICE=$$(ls /dev/cu.usbmodemPD* 2>/dev/null | head -1); \
	if [ -z "$$DEVICE" ]; then \
		echo "Error: No Playdate found. Connect via USB and unlock the device."; \
		exit 1; \
	fi; \
	echo "Putting Playdate into Data Disk mode..."; \
	$(PDUTIL) $$DEVICE datadisk; \
	echo "Waiting for PLAYDATE volume to mount..."; \
	TRIES=0; \
	while [ ! -d /Volumes/PLAYDATE/Games ] && [ $$TRIES -lt 30 ]; do \
		sleep 1; \
		TRIES=$$((TRIES + 1)); \
	done; \
	if [ ! -d /Volumes/PLAYDATE/Games ]; then \
		echo "Error: PLAYDATE volume did not mount after 30s."; \
		exit 1; \
	fi; \
	echo "Copying $(PRODUCT) to Playdate..."; \
	rm -rf /Volumes/PLAYDATE/Games/$(PRODUCT); \
	cp -R $(PRODUCT) /Volumes/PLAYDATE/Games/; \
	echo "Ejecting Playdate (will reboot)..."; \
	diskutil eject /Volumes/PLAYDATE; \
	echo "Done! Playdate will reboot with $(PRODUCT) installed."
