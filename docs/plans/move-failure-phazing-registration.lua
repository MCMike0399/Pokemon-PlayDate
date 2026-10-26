-- Add to the root-owned harness build overlay after production dependencies
-- and dev/contracts have loaded. Do not add to the production import path.
import "dev/whirlwindContracts"
Contracts.register("whirlwind", WhirlwindContracts.run)
import "dev/moveFailureContracts"
Contracts.register("move-failure", MoveFailureContracts.run)
