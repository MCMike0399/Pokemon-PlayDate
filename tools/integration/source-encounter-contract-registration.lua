-- Root-only harness registration; no production/dev import or baseline edited.
import "dev/sourceEncounterContracts"
Contracts.register("source-encounters", SourceEncounterContracts.run)
