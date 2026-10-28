-- Root adds this to a private harness overlay, after root-api.patch imports.
import "dev/fieldWorldContracts"
Contracts.register("field-world",FieldWorldContracts.run)
