-- Prepared root-only harness overlay snippet. Do not import in production.
import "dev/fieldMoveContracts"
Contracts.register("field-moves", FieldMoveContracts.run)
