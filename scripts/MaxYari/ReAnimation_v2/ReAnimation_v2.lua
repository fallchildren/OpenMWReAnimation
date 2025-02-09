local mp = "scripts/MaxYari/ReAnimation_v2/"

local omwself = require('openmw.self')
local types = require('openmw.types')
local core = require("openmw.core")

local animation = require('openmw.animation')
local I = require('openmw.interfaces')
local animManager = require(mp .. "scripts/anim_manager")
local gutils = require(mp .. "scripts/gutils")

local animations = {}

local function cloneAnimOptions(opts)
    local newOpts = gutils.shallowTableCopy(opts)
    if type(opts.priority) ~= "number" then
        newOpts.priority = gutils.shallowTableCopy(opts.priority)
    end
    return newOpts
end

local function unwrapAndAdd(anim)
    print("registering animation"  .. anim.groupname)
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

I.AnimationController.addPlayBlendedAnimationHandler(function(groupname, options)
    -- Learn parent options of animations
    for _, anim in ipairs(animations) do
        if anim.parent and anim.parent == groupname then
            anim.parentOptions = cloneAnimOptions(options)
        end
        if anim.animationHandlerThunk then
            anim.animationHandlerThunk(groupname, options)
        end
    end

    -- Starting override anims
    for _, anim in ipairs(animations) do
        if animation.hasGroup(omwself, anim.groupname) and anim.startOnAnimEvent
            and anim.parent == groupname and ((not anim.playerOnly) or (omwself.type == types.Player)) then
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
    for _, anim in ipairs(animations) do
        if (not anim.playerOnly) or (omwself.type == types.Player) then
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
    interfaceName = "ReAnimation_v2",
    interface = {
        version = 1,
        addAnimationOverwrite = unwrapAndAdd,
    },
    engineHandlers = {
        onUpdate = onUpdate,
    }
}
