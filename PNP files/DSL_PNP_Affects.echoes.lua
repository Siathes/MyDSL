-- Affects Echoes Script
-- 4/6/2015
-- v4.01j
--

dslpnp.affects = dslpnp.affects or {}
dslpnp.affects.echoes = dslpnp.affects.echoes or {}

local spell_info = {
    amnesia = {"Your mind becomes fuzzy; you have problems remembering one of your spells...","Your amnesia subsides."},
    armor = {"You feel someone protecting you.","You feel less armored."},
    berserk = {"Your pulse races as you are consumed by rage!","You feel your pulse slow down."},
    bleeding = {"slashes at your body, opening up a nasty wound!","The flow of blood ceases."},
    bless = {"You feel righteous.","You feel less righteous."},
    blindness = {"You are blinded!","You can see again."},
    blur = {"The outline of your form becomes blurred, shifting and wavering.","Your body image clears up."},
    caltraps = {"Small spikes fall to the ground, painfully digging into your feet.","You painfully pluck the last caltrap."},
    charm = {"",{"You feel more self-confident.","You regain your free will."}},
    courage = {"You feel more courageous.","Your command of your skills returns."},
    curse = {"You feel unclean.","The curse wears off."},
    disembowl = {"You swing your weapon powerfully into .*'s stomach!",""},
    disorientation = {"you feel the movement disorient you!",""},
    distortion = {"You begin to feel very distorted as your vision becomes blurry.","Your mind is no longer distorted."},
    endurance = {"You feel a holy endurance run through your veins.","You feel the divine strength leave your body."},
    enlarge = {"Your body trembles and shivers in pain as you grow larger!", "You feel smaller!"},
    entwine = {"You swing your flails entwining .*!",""},
    fervor = {"You are filled with righteous fervor.",""},
    flurry = {"You spin your swords in a flurry on .*!",""},
    fly = {"Your feet rise off the ground.",{"You float gently to the ground.","You slowly float to the ground."}},
    forget = {"Your skills feel clumsy and unpracticed.",""},
    frenzy = {"You are filled with holy wrath!","Your rage ebbs."},
    furnace = {"You are protected from fire.","Your rune of furnace protection has expired."},
    fury = {"An inner anger takes over your emotions!","The fury within you wears off."},
    haste = {"You feel yourself moving more quickly.",{"You feel yourself slow down.","You feel yourself slowing down."}},
    haze = {"Your mind becomes hazy as your thoughts begin to race.","Your struggle to break from the haze succeeds."},
    infravision = {"Your eyes glow red.","You no longer see in the dark."},
    inspire = {"The zeal of the crusader infects his allies.","The zeal of the crusader wears off."},
    invisibility = {"You fade out of existence.","You are no longer invisible."},
    jawbind = {"net closes over your jaws holding them closed!","The snare around your jaw breaks free."},
    leprosy = {"You scream in agony as your skin begins to rot.","Your skin ceases to decay."},
    litany = {"Your litany inspires you, infusing you with",""},
    nondetect = {"You are immune to detection.", "Your detection immunity wears off."},
    plague = {"You scream in agony as plague sores erupt from yoru skin.","Your sores vanish."},
    poison = {{"You choke and gag.","You feel very sick."},{"A warm feeling runs through your body.","You feel less sick."}},
    prayer = {"A feeling of divinity overtakes your presence.",""},
    purity = {"The purity of your purpose is countenanced.",""},
    rebuke = {"You are inspired to a rightous wrath!",""},
    reduce = {"Your body twists and shivers as you shrink to a smaller size!", "You feel larger!"},
    riot = {"You are filled with a terrible fury!","You no longer feel so angry."},
    sanctuary = {"You are surrounded by a white aura.","The white aura around your body fades."},
    shadowform = {"You fade into the darkened form of a shadow.","You return to your material form."},
    shield = {"You are surrounded by a force shield.","Your force shield shimmers then fades away."},
    sleep = {"You feel very sleepy ..... zzzzzz.",""},
    slow = {"You feel yourself slowing d o w n...","You feel yourself speed up."},
    sneak = {"","You no longer feel stealthy."},
    soulsight = {"You can now see souls.","You no longer see soul auras"},
    taunt = {"shouts a harsh string of insults at you! That little pipsqueak! KILL!! KILL!!","You begin to relax."},
    warcry = {"You yell out a loud warcry!","Your warcry wears off."},
    weaken = {"You feel your strength slip away.","You feel stronger."},
    wingbind = {"Your wings are tangled in a rope.","The rope entangling your wings breaks free."},
    yank = {"You head out of the room, dragging .*\\.",""},
    ["abandon hope"] = {"You feel a wave of depression surround you as you abandon all hope.","You regain your hope in life."},
    ["antimagic shell"] = {"You feel safe as a mystical shield surrounds your body.", "You no longer feel safe as the mystical shield fades away."},
    ["bark skin"] = {"Your skin is protected by bark.","The bark protecting your skin vanishes."},
    ["bind soul"] = {"You feel a mystical force bind your movement!","You feel the binding force fade away."},
    ["bone blight"] = {"You feel a terrible pain in your limbs.","Your limbs feel strong once more."},
    ["bugbear bite"] = {"",""},
    ["change sex"] = {"You feel different.","Your body feels familiar again."},
    ["cut eyes"] = {"slashes at your face, opening up a cut above your eyes!","You wipe the blood out of your eyes."},
    ["dark essence"] = {"You are surrounded by a blackened essence.","The dark essence subsides from your soul."},
    ["detect evil"] = {"","The red in your vision disappears."},
    ["detect good"] = {"","The gold in your vision disappears."},
    ["detect hidden"] = {"Your awareness improves.","You feel less aware of your surroundings."},
    ["detect invis"] = {"","You no longer see invisible objects."},
    ["detect magic"] = {"","The detect magic wears off."},
    ["dirt kicking"] = {"kicks dirt in your eyes!","You rub the dirt out of your eyes."},
    ["divine protection"] = {"You are granted divine protection.","Your divine protection wears off."},
    ["enchanting touch"] = {{"You glow with a blue aura.","You glow with a bright blue aura.","You glow with a brilliant white aura.","You glow with a gleaming white aura.","You glow with a brilliant golden aura."},"Your enchantment fades."},
    ["enhanced recovery"] = {"You feel blessed with a vitalizing aura.","You feel the divine vitalization leave your body."},
    ["faerie fire"] = {"You are surrounded by a pink outline.","The pink aura around you fades away."},
    ["fake illness"] = {{"Your tongue turns black.",""},"Your illness subsides."},
    ["favor of the gods"] = {"","The feeling of righteousness fades."},
    ["find familiar"] = {{"A black cat slinks into the light and rubs against your leg.","A black raven flutters down from above and lands on your shoulder."},{"A black cat stops following you.","A raven stops following you."}},
    ["flash bomb"] = {"You've been blinded!!","You rub your eyes. Hey!! All the little flashing spots are gone!"},
    ["focus aggression"] = {"Your thoughts become concise and focused on killing!","You are no longer focused on your aggression."},
    ["giant strength"] = {"Your muscles surge with heightened power!","You feel weaker."},
    ["holy flame"] = {"Holy flames errupt all about you!","The holy flames about your body subside."},
    ["holy presence"] = {"You feel a holy presence protecting you.","You feel the holy presence leave your body."},
    ["influence confidence"] = {"Your confidence in yourself grows stronger.","You are no longer confident in your hitting ability."},
    ["killing rage"] = {"Screaming a battle cry, you fly into a rage!","You calm down as the battlerage leaves you."},
    ["know languages"] = {"You broaden your language horizons.","Your ability to understand all words fades."},
    ["nature growth"] = {"The forces of nature grow inside of you!","The forces of nature leave your body."},
    ["pass door"] = {"You turn translucent.","You feel solid again."},
    ["prevent recovery"] = {"Your body feels very weak as your ability to heal is drained.","You feel the strain on your health lifted."},
    ["protection evil"] = {"You feel holy and pure.","You feel less protected."},
    ["protection good"] = {"You feel aligned with darkness.","You feel less protected."},
    ["protection neutral"] = {"You are protected from neutral people.","You feel less protected."},
    ["self projection"] = {"Your image projects out slightly in front of you.","Your projected image suddenly disappears."},
    ["shield of words"] = {"You feel protected.","Your protection fades away."},
    ["song of war"] = {"The melody of the Song of War fills your mind.","You no longer hear the melody of the Song of War in your mind."},
    ["stone skin"] = {"Your skin turns to stone.","Your skin feels soft again."},
    ["sure striking"] = {"You strike more surely.","Your ever sure strikes faulter."},
    ["water breathing"] = {"You feel strange as you start having trouble breathing air.","You start gasping for air as you can breath normally again!"},
    ["we come, we come"] = {{"The song enrages your groupmates and demoralizes your enemies.","Your song enrages your groupmates and demoralized your enemies."},"The bard's ally song leaves your mind"},
    ["withstand death"] = {"Death has no power over you.","You shiver as you become susceptible to death again."},
}

local function make_triggers()
    local upstr = [[raiseEvent("affectAdd","%s")]]
    local downstr = [[raiseEvent("affectRemove","%s")]]
    local index = 1

    -- kill old triggers
    while dslpnp.triggers.exists("Affects Echoes Trigger " .. index) do
        dslpnp.triggers.kill("Affects Echoes Trigger " .. index)
        index = index + 1
    end
    index = 1

    -- create new triggers
    for k,v in pairs(spell_info) do
        if type(v[1]) == "string" then
            if v[1] ~= "" then
                dslpnp.triggers.register("Affects Echoes Trigger " .. index,"regex",v[1],string.format(upstr,k),true)
                index = index + 1
            end
        else
            for k2,v2 in ipairs(v[1]) do
                if v2 ~= "" then
                    dslpnp.triggers.register("Affects Echoes Trigger " .. index,"regex",v2,string.format(upstr,k),true)
                    index = index + 1
                end
            end
        end
        if type(v[2]) == "string" then
            if v[2] ~= "" then
                dslpnp.triggers.register("Affects Echoes Trigger " .. index,"regex",v[2],string.format(downstr,k),true)
                index = index + 1
            end
        else
            for k2,v2 in ipairs(v[2]) do
                if v2 ~= "" then
                    dslpnp.triggers.register("Affects Echoes Trigger " .. index,"regex",v2,string.format(downstr,k),true)
                    index = index + 1
                end
            end
        end
    end
end

local function toggle(setVal)
    dslpnp.affects.echoes.Active = dslpnp.toggle("affects : echoes",dslpnp.affects.echoes.Active, setVal)
    -- need to disable all the triggers if inactive and re-enable if active
    local index = 1

    if dslpnp.affects.echoes.Active then
        while dslpnp.triggers.exists("Affects Echoes Trigger " .. index) do
            dslpnp.triggers.enable("Affects Echoes Trigger " .. index)
            index = index + 1
        end
    else
        while dslpnp.triggers.exists("Affects Echoes Trigger " .. index) do
            dslpnp.triggers.disable("Affects Echoes Trigger " .. index)
            index = index + 1
        end
    end
end

local function config()
    make_triggers()
    raiseEvent("onToggle","affects.echoes","on")
end

function dslpnp.affects.echoes.eventHandler(event, ...)
    if event == "onToggle" and arg[1] == "affects.echoes" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "affects.echoes" then
        config()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.affects.echoes.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.affects.echoes.eventHandler")
