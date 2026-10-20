-- Stable gameplay IDs remain independent of the checked-in asset filenames.
-- The catalog and coverage validator use this same explicit alias manifest.
PokemonArt = {}
local manifest <const> = assert(json.decodeFile("data/pokemon-art.json"))
assert(manifest.schema == 1, "unsupported Pokemon art manifest")
local aliases <const> = manifest.aliases

function PokemonArt.path(species, view)
    assert(view == "front" or view == "back", "invalid Pokemon art view")
    return "images/pokemon/" .. (aliases[species] or species) .. "-" .. view
end
