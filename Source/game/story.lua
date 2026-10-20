-- game/story.lua — The opening questline (Gen 1 first minutes)
--
-- A tiny linear stage machine driven from the overworld's explore substate:
--
--   pre_oak     game starts in Red's bedroom; walking into the Route 1
--               grass strip triggers Oak's "Don't go out!" and a fade
--               into the lab
--   lab_greet   transient: set right before the fade; entering the lab
--               fires Oak's welcome speech
--   choose      A on a POKE BALL on the lab table picks the starter;
--               BLUE takes the counter pick
--   pre_rival   walking toward the lab exit makes BLUE challenge you
--   rival_fight transient: the scripted trainer battle is running
--   goodbye     back in the lab after the battle, BLUE taunts and leaves
--   done        free play (debug "Skip Intro" jumps straight here)
--
-- Stages are flipped BEFORE their dialog is pushed, so a trigger can never
-- fire twice while its own dialog overlay is up.

Story = {
    stage = "pre_oak",
    starter = nil,        -- chosen species key
    rivalStarter = nil,   -- BLUE's counter pick
    rivalOutcome = nil,   -- true = player won the intro fight
}

local STARTER_LEVEL <const> = 5
local BALL_TILE <const> = 37   -- Pb: table with a POKE BALL on it
local TABLE_TILE <const> = 28  -- Tb: plain table (ball taken)

local COUNTER <const> = {
    bulbasaur = "charmander",
    charmander = "squirtle",
    squirtle = "bulbasaur",
}

-- The three starter balls on Oak's table (grid coords in oaks_lab).
-- Gen 1 left-to-right order: CHARMANDER, SQUIRTLE, BULBASAUR.
local BALLS <const> = {
    { x = 6, y = 2, species = "charmander" },
    { x = 7, y = 2, species = "squirtle" },
    { x = 8, y = 2, species = "bulbasaur" },
}

-- ------------------------------------------------------------
-- Dialog content (lines kept short for the 2-line dialog box)
-- ------------------------------------------------------------

Story.openingLines = {
    "OAK: Hello there! Welcome to the world of POKEMON!",
    "My name is OAK. People call me the POKEMON PROF.",
    "This world is inhabited by creatures called POKEMON!",
    "For some people, POKEMON are pets. Others use them for fights.",
    "Myself... I study POKEMON as a profession.",
    "Now, what is your name? ...Right! RED!",
    "This is my grandson. He's been your rival since you were a baby.",
    "...Erm, what is his name again? Oh, that's right -- BLUE!",
    "RED! Your very own POKEMON legend is about to unfold!",
    "A world of dreams and adventures awaits! Let's go!",
}

local OAK_STOP <const> = {
    "OAK: Hey! Wait! Don't go out!",
    "It's unsafe! Wild POKEMON live in tall grass!",
    "You need your own POKEMON for your protection.",
    "I know! Here, come with me!",
}

local LAB_GREET <const> = {
    "BLUE: Gramps! I'm fed up with waiting!",
    "OAK: BLUE? Let me think... Oh, that's right, I told you to come! Just wait!",
    "Here, RED! There are 3 POKEMON here.",
    "When I was young, I was a serious POKEMON trainer!",
    "In my old age, I have only 3 left, but you can have one! Choose!",
}

local RIVAL_CHALLENGE <const> = {
    "BLUE: Wait, RED! Let's check out our POKEMON!",
    "Come on, I'll take you on!",
}

local GOODBYE_WON <const> = {
    "BLUE: WHAT? Unbelievable! I picked the wrong POKEMON!",
    "Okay! I'll make my POKEMON fight to toughen it up!",
    "RED! Gramps! Smell you later!",
}

local GOODBYE_LOST <const> = {
    "BLUE: Yeah! Am I great or what?",
    "Okay! I'll make my POKEMON fight to toughen it up!",
    "RED! Gramps! Smell you later!",
}

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

function Story.isActive()
    return Story.stage ~= "done"
end

-- New game: the questline starts in Red's bedroom
function Story.begin()
    Story.stage = "pre_oak"
    switchZone("reds_house_2f")
end

local function setLabTile(gx, gy, id)
    local lab = zoneRegistry.oaks_lab
    lab.tiles[gy + 1][gx + 1] = id
    if currentZone == lab then
        setOverworldTile(gx, gy, id)
    end
end

local function takeBall(species)
    for _, ball in ipairs(BALLS) do
        if ball.species == species then
            setLabTile(ball.x, ball.y, TABLE_TILE)
        end
    end
end

local function restoreBalls()
    for _, ball in ipairs(BALLS) do
        setLabTile(ball.x, ball.y, BALL_TILE)
    end
end

-- Normal B2W2 Lv5 initialization yields the protected intro pairs:
-- Tackle/Growl, Scratch/Growl, or Tackle/Tail Whip. No special override.
local function starterPokemon(species)
    return Pokemon(species, STARTER_LEVEL)
end

-- ------------------------------------------------------------
-- Triggers — called from ExploreSubstate:update every frame.
-- Returns true when it consumed the frame (pushed a dialog or
-- changed state); the caller must stop processing.
-- ------------------------------------------------------------

function Story.check(game, overworldState)
    if Story.stage == "done" then return false end
    -- Never re-trigger while a dialog/debug overlay already owns input
    if not game.machine:is("overworld") then return false end

    local player = game.player
    local stage = Story.stage

    -- Scene triggers: fire on BEING somewhere, not on a step
    if stage == "lab_greet" and currentZone == zoneRegistry.oaks_lab then
        Story.stage = "choose"
        game.machine:push("dialog", LAB_GREET)
        return true
    end

    if stage == "goodbye" and currentZone == zoneRegistry.oaks_lab then
        Story.stage = "done"
        local lines = Story.rivalOutcome and GOODBYE_WON or GOODBYE_LOST
        game.machine:push("dialog", lines, function()
            local blue = game.npcManager:findByName("BLUE")
            if blue then game.npcManager:removeNPC(blue) end
        end)
        return true
    end

    -- Step triggers: fire on landing on a tile
    if not (player and player.stepJustFinished) then return false end

    -- Oak stops you at the Route 1 grass strip and escorts you to the lab
    if stage == "pre_oak" and currentZone == zoneRegistry.pallet_town
       and player.gridY <= 2 then
        game.machine:push("dialog", OAK_STOP, function()
            Story.stage = "lab_greet"
            -- Drop the player a clear tile below Oak so the two sprites
            -- don't stack into one tall figure
            overworldState.sub:change("doorWarp",
                { to = "oaks_lab", toX = 5, toY = 5, facing = "up" })
        end)
        return true
    end

    -- BLUE blocks the lab exit and challenges you
    if stage == "pre_rival" and currentZone == zoneRegistry.oaks_lab
       and player.gridY >= 8 then
        game.machine:push("dialog", RIVAL_CHALLENGE, function()
            Story.stage = "rival_fight"
            local blue = game.npcManager:findByName("BLUE")
            local enemy = starterPokemon(Story.rivalStarter)
            game.machine:change("battle", game.playerPokemon, enemy, blue)
        end)
        return true
    end

    return false
end

-- A-press on a facing tile — called from ExploreSubstate:handleInput
-- before NPC interaction. Returns true if the press was consumed.
function Story.tryInteract(game, fx, fy)
    if Story.stage ~= "choose" or currentZone ~= zoneRegistry.oaks_lab then
        return false
    end
    for _, ball in ipairs(BALLS) do
        if ball.x == fx and ball.y == fy
           and currentZone.tiles[fy + 1][fx + 1] == BALL_TILE then
            Story.chooseStarter(game, ball.species)
            return true
        end
    end
    return false
end

function Story.chooseStarter(game, species)
    Story.starter = species
    Story.rivalStarter = COUNTER[species]
    Story.stage = "pre_rival"
    game.playerPokemon = starterPokemon(species)
    takeBall(species)
    takeBall(Story.rivalStarter)
    game.machine:push("dialog", {
        "OAK: This POKEMON is really energetic!",
        "RED received a " .. pokemonData[species].name .. "!",
        "BLUE: I'll take this one, then!",
        "BLUE received a " .. pokemonData[Story.rivalStarter].name .. "!",
    })
end

-- Called by BattleState when any battle resolves
function Story.notifyBattleEnd(won)
    if Story.stage == "rival_fight" then
        Story.rivalOutcome = won
        Story.stage = "goodbye"
    end
end

-- ------------------------------------------------------------
-- Debug / autopilot controls
-- ------------------------------------------------------------

-- Jump straight to free play (squirtle starter unless one was chosen)
function Story.skipIntro(game)
    if Story.stage ~= "done" then
        Story.starter = Story.starter or "squirtle"
        Story.rivalStarter = COUNTER[Story.starter]
        Story.stage = "done"
    end
    if not game.playerPokemon then
        game.playerPokemon = starterPokemon(Story.starter)
    end
    takeBall(Story.starter)
    takeBall(Story.rivalStarter)
end

-- Restart the questline from the bedroom
function Story.resetIntro(game)
    Story.stage = "pre_oak"
    Story.starter = nil
    Story.rivalStarter = nil
    Story.rivalOutcome = nil
    game.playerPokemon = nil
    restoreBalls()
    -- the post-intro rematch BLUE forgets the earlier fight
    for _, def in ipairs(zoneRegistry.pallet_town.npcDefs) do
        if def.name == "BLUE" then def.interacted = false end
    end
    switchZone("reds_house_2f")
end
