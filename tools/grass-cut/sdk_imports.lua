-- Root adds this through the private harness overlay, after production owners.
import "dev/grassCutContracts"
Contracts.register("grass-cut", GrassCutContracts.run)
