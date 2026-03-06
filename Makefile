SDK = $(PLAYDATE_SDK_PATH)
PDC = $(SDK)/bin/pdc
PRODUCT = PokemonPoC.pdx

build: clean compile run

clean:
	rm -rf $(PRODUCT)

compile:
	$(PDC) Source $(PRODUCT)

run:
	open -a "$(SDK)/bin/Playdate Simulator.app" $(PRODUCT)
