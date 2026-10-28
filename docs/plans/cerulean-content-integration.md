# Root integration: Cerulean content

This worker merges exact foundation `9f3e37b` and owns only new content files.
No Simulator, native execution, push or further delegation occurred.

After 5.2 acceptance, import after SourceEvents/SourceActors/SpriteFactory:

```lua
import "data/ceruleanContent"
CeruleanContent.install()
```

The existing source profile in `SourceMaps.legacyProfiles` uses these registered
resolvers. Do not add another geometry provider or regional map constructor.
Register the root-only SDK suite in the harness overlay and its explicit fixture:

```lua
import "dev/ceruleanContentContracts"
Contracts.register("cerulean-content", CeruleanContentContracts.run)
```

Before activating the candidate manifest, root must address these observed
foundation seams in shared files outside worker ownership:

- `SourceEvents.registerEventSource` currently accepts only `:objects:N`. Permit
  `:background_events:N` as well, then call `CeruleanContent.installSigns()`.
- `Zone.fromMapDefinition` currently permits only MapBindings/PewterBindings as
  bindingAdapter. The shared constructor passes SourceBindings, which needs to
  be accepted for new source-profile maps.
- `SourceMaps.connection` must honor `blocked_connections`, and `warpSpec` must
  honor explicit `blocked_events` before binding a newly available target.
  Preserve reciprocal return safety when an outside ingress is still blocked.
- The legacy `TrainerEvents` animation path still calls PewterSprites.stepImage.
  Route new source actors through SourceActors with their content profile.
  Verify actual source trainer sight/approach/return with root's native journeys.

These are code-reading findings, not worker-observed runtime failures. No shared
module was patched here. The candidate SDK suite exercises detached content; it
does not substitute for creating real Zones and walking the campaign.

Promote `Source/data/ceruleanSourceMaps.json` to `sourceMaps.json` and its paired
`ceruleanMapCache` bytes to `sourceMapCache` only during root integration. Open
old boundary gates and museum warps deliberately once their story dependencies
are ready. Regenerate the shared cache after any manifest change. The worker's
`candidate_manifest` helper is for this pre-activation branch; remove/update that
helper and the extension witness inventory tests when promoting the additions.

The story worker can use `CeruleanContent.text(label)`, `trainers()` and
`rivalClasses()` without duplicating pinned text or parties. Reserved ordinary
registrations are absent for:

- `pokered:BILLS_HOUSE:objects:1`, `:2`, `:3`;
- `pokered:MT_MOON_B2F:objects:1`, `:6`, `:7`;
- `pokered:CERULEAN_GYM:objects:1`.

Register their descriptors under their own content name and register
CeruleanContent.text for that name. Root composes source visibility/allowed
script positions for Bill, fossils, rival and guard actors before activation;
the source hide/show declarations are in `sourceSlice/scripts.json`.
