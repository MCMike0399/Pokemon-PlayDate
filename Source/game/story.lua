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

Story = {}
local boundContext
function Story.bind(game) boundContext=game end
function Story.currentContext() return boundContext end
function Story.get(game)
    game=game or boundContext
    return game and game.session:getIntro() or {stage="pre_oak"}
end
local function update(game,changes)
    local tuple=Story.get(game)
    for key,value in pairs(changes) do tuple[key]=value end
    assert(game.session:setIntro(tuple))
end
-- Authored map dialogue closures have a read-only view of the installed owner.
local fields={stage=true,starter=true,rivalStarter=true,rivalOutcome=true}
setmetatable(Story,{__index=function(_,key) if fields[key] then return Story.get()[key] end end,
    __newindex=function(t,key,value) assert(not fields[key],"Story fields are session-owned"); rawset(t,key,value) end})

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
-- Oak's speech. engine/movie/oak_speech/oak_speech.asm OakSpeech
-- and data/text/text_2.asm _OakSpeechText1 through _OakSpeechText3.
-- Names come from the session. The fallback matches the codec default.
-- ------------------------------------------------------------

Story._names = setmetatable({}, {__mode = "k"})

-- One read for Oak's speech, the naming screen, and the continue box.
-- Lane E's codec patch is the title() return. This function does not
-- grow a second source when that return stops being RED / BLUE.
function Story.readName(game, who, field, fallback)
    local session = game and game.session
    local bag = session and Story._names[session]
    if bag and type(bag[who]) == "string" and bag[who] ~= "" then return bag[who] end
    if session and type(session.title) == "function" then
        local ok, title = pcall(session.title, session)
        if ok and type(title) == "table" and type(title[field]) == "string" and title[field] ~= "" then
            return title[field]
        end
    end
    return fallback
end

function Story.playerName(game)
    return Story.readName(game, "player", "playerName", "RED")
end

function Story.rivalName(game)
    return Story.readName(game, "rival", "rivalName", "BLUE")
end

function Story.remember(game, who, name)
    if who ~= "player" and who ~= "rival" then return false end
    if type(name) ~= "string" or name == "" then return false end
    local session = game and game.session
    if session then
        local bag = Story._names[session]
        if not bag then
            bag = {}
            Story._names[session] = bag
        end
        bag[who] = name
        local setter = who == "player" and session.setPlayerName or session.setRivalName
        if type(setter) == "function" then pcall(setter, session, name) end
    end
    return true
end

-- Pokemon codec accepts 1-10 printable ASCII. Longer or tile glyphs wait
-- for the lane E name field. The naming screen still produces them.
function Story.storeNickname(mon, name)
    if not mon or type(name) ~= "string" or name == "" then return false end
    if #name > 10 or name:find("[^ -~]") then return false end
    mon.name = name
    return true
end

function Story.oakSteps()
    return {
        {kind = "text", source = "OakSpeechText1", lines = {
            "Hello there!",
            "Welcome to the world of POKEMON!",
            "My name is OAK! People call me the POKEMON PROF!",
        }},
        {kind = "text", source = "OakSpeechText2", cry = "nidorina", lines = {
            "This world is inhabited by creatures called POKEMON!",
            "For some people, POKEMON are pets. Others use them for fights.",
            "Myself...",
            "I study POKEMON as a profession.",
        }},
        {kind = "text", source = "IntroducePlayerText", lines = {
            "First, what is your name?",
        }},
        {kind = "name", who = "player"},
        {kind = "text", source = "YourNameIsText", lines = function(game)
            return {"Right! So your name is " .. Story.playerName(game) .. "!"}
        end},
        {kind = "text", source = "IntroduceRivalText", lines = {
            "This is my grandson. He's been your rival since you were a baby.",
            "...Erm, what is his name again?",
        }},
        {kind = "name", who = "rival"},
        {kind = "text", source = "HisNameIsText", lines = function(game)
            return {"That's right! I remember now! His name is " .. Story.rivalName(game) .. "!"}
        end},
        {kind = "text", source = "OakSpeechText3", lines = function(game)
            local player = Story.playerName(game)
            return {
                player .. "!",
                "Your very own POKEMON legend is about to unfold!",
                "A world of dreams and adventures with POKEMON awaits! Let's go!",
            }
        end},
    }
end

function Story.refreshOpeningLines(game)
    local lines = {}
    for _, step in ipairs(Story.oakSteps()) do
        if step.kind == "text" then
            local chunk = step.lines
            if type(chunk) == "function" then chunk = chunk(game) end
            for _, line in ipairs(chunk) do lines[#lines + 1] = line end
        end
    end
    Story.openingLines = lines
    return lines
end

local OAK_STOP <const> = {
    "OAK: Hey! Wait! Don't go out!",
    "It's unsafe! Wild POKEMON live in tall grass!",
    "You need your own POKEMON for your protection.",
    "I know! Here, come with me!",
}

function Story.labGreet(game)
    local player = Story.playerName(game)
    local rival = Story.rivalName(game)
    return {
        rival .. ": Gramps! I'm fed up with waiting!",
        "OAK: " .. rival .. "? Let me think... Oh, that's right, I told you to come! Just wait!",
        "Here, " .. player .. "! There are 3 POKEMON here.",
        "When I was young, I was a serious POKEMON trainer!",
        "In my old age, I have only 3 left, but you can have one! Choose!",
    }
end

function Story.rivalChallenge(game)
    return {
        Story.rivalName(game) .. ": Wait, " .. Story.playerName(game) .. "! Let's check out our POKEMON!",
        "Come on, I'll take you on!",
    }
end

function Story.goodbye(game, won)
    local rival = Story.rivalName(game)
    local player = Story.playerName(game)
    local first = won and (rival .. ": WHAT? Unbelievable! I picked the wrong POKEMON!")
        or (rival .. ": Yeah! Am I great or what?")
    return {
        first,
        "Okay! I'll make my POKEMON fight to toughen it up!",
        player .. "! Gramps! Smell you later!",
    }
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

function Story.isActive(game)
    return Story.get(game).stage ~= "done"
end

-- New game: the questline starts in Red's bedroom
function Story.begin(game,seed)
    assert(game,"Story.begin requires GameContext")
    return game:beginNewSession(seed)
end

local function setLabTile(gx, gy, id)
    zoneRegistry.oaks_lab:setTile(gx, gy, id)
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
local function starterPokemon(game, species, origin)
    local mon=assert(Specimen.createForSession(game.session,species,STARTER_LEVEL,origin or "starter",
        origin=="trainer" and Specimen.blueTrainerPolicy("authored:oaks_lab:npc:2") or nil))
    return mon
end

-- ------------------------------------------------------------
-- Triggers — called from ExploreSubstate:update every frame.
-- Returns true when it consumed the frame (pushed a dialog or
-- changed state); the caller must stop processing.
-- ------------------------------------------------------------

function Story.check(game, overworldState)
    if (game.session and game.session:introStage() or "pre_oak") == "done" then return false end
    -- Never re-trigger while a dialog/debug overlay already owns input
    if not game.machine:is("overworld") then return false end

    local player = game.player
    local stage = Story.get(game).stage

    -- Scene triggers: fire on BEING somewhere, not on a step
    if stage == "lab_greet" and currentZone == zoneRegistry.oaks_lab then
        update(game,{stage="choose"})
        game.machine:push("dialog", Story.labGreet(game))
        return true
    end

    if stage == "goodbye" and currentZone == zoneRegistry.oaks_lab then
        update(game,{stage="done"})
        local lines = Story.goodbye(game, Story.get(game).rivalOutcome)
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
            update(game,{stage="lab_greet"})
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
        local session=game.session
        game.machine:push("dialog", Story.rivalChallenge(game), function()
            if game.session~=session or not Specimen.isActiveSession(session) or not game.machine:is("overworld") or not session:party():firstUsable() then return false,"stale-rival-creation" end
            local blue = game.npcManager:findByName("BLUE")
            local enemy = starterPokemon(game, Story.get(game).rivalStarter, "trainer")
            update(game,{stage="rival_fight"})
            assert(FieldBattle.start(game, game:getPlayerPokemon(), enemy, blue))
        end)
        return true
    end

    return false
end

-- A-press on a facing tile — called from ExploreSubstate:handleInput
-- before NPC interaction. Returns true if the press was consumed.
function Story.tryNameRater(game, fx, fy)
    if not NameRater.hooked() then return false end
    if type(currentZone) ~= "table" or type(currentZone.sourceEventsAt) ~= "function" then
        return false
    end
    for _, event in ipairs(currentZone:sourceEventsAt(fx, fy)) do
        if event.id == NameRater.OBJECT then
            return NameRater.present(game) == true
        end
    end
    return false
end

function Story.tryInteract(game, fx, fy)
    if Story.tryNameRater(game, fx, fy) then return true end
    if Story.get(game).stage ~= "choose" or currentZone ~= zoneRegistry.oaks_lab then
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
    assert(COUNTER[species],"unknown starter")
    assert(game.session:party():count()==0,"starter requires an empty party")
    assert(game:recruit(starterPokemon(game, species)))
    assert(game.session:setIntro({stage="pre_rival",starter=species,rivalStarter=COUNTER[species]}))
    takeBall(species)
    takeBall(Story.get(game).rivalStarter)
    local mon = game:getPlayerPokemon()
    local speciesName = pokemonData[species].name
    game.machine:push("dialog", {
        "OAK: This POKEMON is really energetic!",
    }, function()
        -- naming_screen.asm AskName. Declining keeps the species name.
        Story.promptNickname(game, mon, speciesName, function()
            local rival = Story.rivalName(game)
            local player = Story.playerName(game)
            local got = mon and mon.name or speciesName
            game.machine:push("dialog", {
                player .. " received a " .. got .. "!",
                rival .. ": I'll take this one, then!",
                rival .. " received a " .. pokemonData[Story.get(game).rivalStarter].name .. "!",
            })
        end)
    end)
end

function Story.promptNickname(game, mon, speciesName, done)
    local function finish()
        if done then done(mon and mon.name) end
    end
    if not game or not game.machine or not game.machine.get or not game.machine:get("naming") then
        finish()
        return false
    end
    game.machine:push("naming", {
        kind = "mon",
        speciesName = speciesName,
        ask = true,
        onDone = function(name)
            if type(name) == "string" then Story.storeNickname(mon, name) end
            finish()
        end,
    })
    return true
end

function Story.beginOakSpeech(game)
    Story._oak = {index = 1, game = game}
    if game and game.session then Story._names[game.session] = {} end
    Story.advanceOak(game)
end

function Story.advanceOak(game)
    local cursor = Story._oak
    if not cursor or cursor.game ~= game then return end
    local step = Story.oakSteps()[cursor.index]
    if not step then
        Story._oak = nil
        Story.refreshOpeningLines(game)
        return
    end
    cursor.index = cursor.index + 1
    if step.kind == "text" then
        local lines = step.lines
        if type(lines) == "function" then lines = lines(game) end
        if step.cry and type(KantoAudio) == "table" and type(KantoAudio.playCry) == "function" then
            pcall(KantoAudio.playCry, step.cry)
        end
        game.machine:push("dialog", lines, function()
            Story.advanceOak(game)
        end)
    elseif step.kind == "name" then
        game.machine:push("naming", {
            kind = step.who,
            onDone = function(name)
                if type(name) == "string" then Story.remember(game, step.who, name) end
                Story.advanceOak(game)
            end,
        })
    end
end

-- Called by BattleState when any battle resolves
function Story.notifyBattleEnd(game,won,kind)
    if Story.get(game).stage == "rival_fight" then
        update(game,{rivalOutcome=won,stage="goodbye"})
    end
end

-- ------------------------------------------------------------
-- Debug / autopilot controls
-- ------------------------------------------------------------

-- Jump straight to free play (squirtle starter unless one was chosen)
function Story.skipIntro(game)
    local tuple=Story.get(game)
    local starter=tuple.starter or "squirtle"
    if not game:getPlayerPokemon() then assert(game:recruit(starterPokemon(game, starter))) end
    assert(game.session:setIntro({stage="done",starter=starter,rivalStarter=COUNTER[starter],rivalOutcome=tuple.rivalOutcome}))
    takeBall(starter); takeBall(COUNTER[starter])
end

function Story.resetIntro(game)
    return game:beginNewSession(RulesRNG.snapshot().seed)
end

Story.refreshOpeningLines(nil)
