local mp = "scripts/MaxYari/ReAnimation_v2/"

local omwself = require('openmw.self')
local types = require('openmw.types')
local core = require("openmw.core")

local animation = require('openmw.animation')
local I = require('openmw.interfaces')
local animManager = require(mp .. "scripts/anim_manager")
local gutils = require(mp .. "scripts/gutils")

DebugLevel = 0

local animations = {}
local attackCounters = {}



--- API Functions -----------------------
--- -------------------------------------

local function addAnimationOverride(anim)
    -- print("registering animation"  .. anim.groupname)
    if type(anim.parent) == "table" then
        for _, parent in ipairs(anim.parent) do
            local newAnimation = gutils.shallowTableCopy(anim)
            newAnimation.parent = parent
            table.insert(animations, newAnimation)
        end
    else
        table.insert(animations, anim)
    end
end


--[[ 
params example:
{
    parentGroupname = "weapononehand",
    overrideGroupname = "weapononehand1",
    armatureType = I.ReAnimation.ARMATURE_TYPE.ThirdPerson,
} 
]]

-- This will result in parentAttackGroupname and altAttackGroupname being used one after another.
-- altAttackGroupname textkey timings should match parent textkey timings exactly.
local function addAltAttackAnimations(params)
    if not params.parentAttackGroupname or not params.altAttackGroupname then
        error("addAltAttackAnimation(): parentAttackGroupname or altAttackGroupname were not found in params object.")
        return
    end
    
    local override = {
        parent = params.parentAttackGroupname,
        groupname = params.altAttackGroupname,
        armatureType = params.armatureType,
        condition = function(self)       
            local startKey = self.parentOptions.startkey or self.parentOptions.startKey
            if not gutils.isAttackType(startKey) then
                return false
            end
            local counterKey = self.parent .. gutils.isAttackType(startKey)
            return attackCounters[counterKey] == 1
        end,
        options = function(self, pOptions)
            local opts = gutils.cloneAnimOptions(pOptions)

            -- Since the engine never runs 2 animations with exact same priorities - it's important to make parent animation priority unique to ensure that it will remain running in the background.
            -- Running original animations in the background is important to keep internal engine's character controller satisfied.
            gutils.uniquifyPriority(pOptions)

            pOptions.blendMask = 0
            pOptions.blendmask = 0

            return opts
        end,
        startOnAnimEvent = true
    }
    table.insert(animations, override)
end



--- Core Override handling--------------------------
--- ------------------------------------------------

I.AnimationController.addPlayBlendedAnimationHandler(function(groupname, options)
    if not #animations then return end

    local startKey = options.startkey or options.startKey
    local stopKey = options.stopkey or options.stopKey

    -- Learn parent options of animations
    for _, anim in ipairs(animations) do
        if anim.parent and anim.parent == groupname then
            anim.parentOptions = gutils.cloneAnimOptions(options)
        end
    end

    -- Count attacks
    if gutils.isAttackTypeStart(startKey) then
        local key = groupname .. gutils.isAttackType(startKey)
        if not attackCounters[key] then attackCounters[key] = -1 end
        attackCounters[key] = (attackCounters[key] + 1) % 2
    end

    -- Starting override anims
    for _, anim in ipairs(animations) do
        if animation.hasGroup(omwself, anim.groupname) and anim.startOnAnimEvent
            and anim.parent == groupname and gutils.isMatchingArmatureType(anim.armatureType) then
            local shouldStart = anim:condition()
            if shouldStart then
                -- print("Overriding " .. anim.parent .. " with " .. anim.groupname)
                animation.cancel(omwself, anim.groupname)
                I.AnimationController.playBlendedAnimation(anim.groupname, anim:options(options))
                anim.running = true
            end
        end
    end
end)


local function onUpdate(dt)
    if not #animations then return end

    for _, anim in ipairs(animations) do
        if gutils.isMatchingArmatureType(anim.armatureType) then
            local isParentPlaying = nil
            local isPlaying = nil
            local shouldStart = nil
            local shouldStop = nil

            if anim.running then
                isPlaying = animManager.isPlaying(anim.groupname)
                if anim.parent then isParentPlaying = animManager.isPlaying(anim.parent) end

                if not isPlaying then anim.running = false end

                shouldStop = isPlaying and
                    ((anim.stopCondition and anim:stopCondition()) or (anim.parent and not isParentPlaying))
            end

            if anim.startOnUpdate and not anim.running then
                if anim.parent and isParentPlaying == nil then isParentPlaying = animManager.isPlaying(anim.parent) end

                shouldStart = (not anim.parent or isParentPlaying) and anim:condition() and animation.hasGroup(omwself, anim.groupname)
            end

            if shouldStart then
                I.AnimationController.playBlendedAnimation(anim.groupname, anim:options())
                anim.running = true
            end
            if shouldStop then
                animation.cancel(omwself, anim.groupname)
                anim.running = false
            end
        end
    end
end

return {
    interfaceName = "ReAnimation",
    interface = {
        version = 2.5,
        ARMATURE_TYPE = gutils.ARMATURE_TYPE,
        addAnimationOverride = addAnimationOverride,
        addAltAttackAnimations = addAltAttackAnimations
    },
    engineHandlers = {
        onUpdate = onUpdate,
    }
}
