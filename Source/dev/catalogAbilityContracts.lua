-- The trusted exporter must observe new battle-owned weather, without claiming
-- it can rewind arbitrary rule/coroutine state through a rendering transaction.
CatalogAbilityContracts={}
function CatalogAbilityContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local owner=game.machine:get("battle")
    local oldBattle,oldRNG=owner.battle,RulesRNG.snapshot()
    local unregister
    local ok,why=pcall(function()
        local battle=Battle(Pokemon("sandshrew",20),Pokemon("rattata",20))
        owner.battle=battle
        battle.effects.weather={turns=5}
        local image=playdate.graphics.image.new(32,32,playdate.graphics.kColorWhite)
        unregister=VisualCatalog.registerExporter("weather-fault",{
            inventory=function()return {images={{path="weather-fault.png",width=32,height=32,category="test",mask=false}}}end,
            writer=function(sink)
                sink.save("weather-fault",image,"test",false)
                battle.effects.weather.turns=4
                return {}
            end,
        })
        local exported,reason=pcall(VisualCatalog.runExporter,"weather-fault",function()end)
        assert(not exported,"weather mutation escaped catalog observation")
        assert(tostring(reason):find("unrestored/unsupported state",1,true),tostring(reason))
        assert(battle.effects:snapshot().turns==4,"unsupported weather was incorrectly described as restored")
    end)
    if unregister then unregister()end
    owner.battle=oldBattle
    RulesRNG.restore(oldRNG)
    report.ok=ok;report.passed=ok and 1 or 0;report.failed=ok and 0 or 1
    report.tests[1]={name="Battle weather side effect is observed and honestly reported as unsupported rollback",ok=ok,error=not ok and tostring(why)or nil}
    return report
end
