local mp = "scripts/MaxYari/ReAnimation_v2/"

local omwself = require('openmw.self')
local camera = require('openmw.camera')
local types = require('openmw.types')

local animation = require('openmw.animation')
local I = require('openmw.interfaces')
local animManager = require(mp .. "scripts/anim_manager")
local gutils = require(mp .. "scripts/gutils")

local attackTypes = { "chop", "slash", "thrust" }
local attackCounters = {}

local selfActor = gutils.Actor:new(omwself)

local function findInList(table, val)
    if type(table) ~= "table" then return 0 end
    for ind, value in ipairs(table) do
        if value == val then return ind end
    end
    return 0
end


local function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

local function isAttackType(key, suffix)
    if suffix then suffix = " " .. suffix end
    if not suffix then suffix = "" end
    for _, type in ipairs(attackTypes) do
        if string.find(key, type .. suffix) then
            return type
        end
    end
    return false
end

local function isAttackTypeStart(key)
    return isAttackType(key, "start")
end

local function cloneAnimOptions(opts)
    local newOpts = gutils.shallowTableCopy(opts)
    if type(opts.priority) ~= "number" then
        newOpts.priority = gutils.shallowTableCopy(opts.priority)
    end
    return newOpts
end

-- Available bone-groups:
-- BoneGroup.LeftArm
-- BoneGroup.LowerBody
-- BoneGroup.RightArm
-- BoneGroup.Torso
local function expandPriority(options)
    if type(options.priority) == "number" then
        options.priority = {
            [animation.BONE_GROUP.LeftArm] = options.priority,
            [animation.BONE_GROUP.LowerBody] = options.priority,
            [animation.BONE_GROUP.RightArm] = options.priority,
            [animation.BONE_GROUP.Torso] = options.priority
        }
    end
end

local function uniquifyPriority(options)
    expandPriority(options)
    if type(options.priority) == "userdata" or type(options.priority) == "table" then
        options.priority[animation.BONE_GROUP.LeftArm] = options.priority[animation.BONE_GROUP.LeftArm] - 1
        options.priority[animation.BONE_GROUP.LowerBody] = options.priority[animation.BONE_GROUP.LowerBody] - 1
    else
        error("Encountered a priority which is not a number, userdata or table. This should never happen. Priority is: " ..
            tostring(options.priority))
    end
end

local function locomotionAnimSpeed()
    local isSneaking = omwself.controls.sneak
    local isRunning = omwself.controls.run

    local moveAnimSpeed = 154.064
    if isSneaking then
        moveAnimSpeed = 33.5452 * 2.8
    elseif isRunning then
        moveAnimSpeed = 222.857
    end

    local maxSpeedMult = 10;
    local speedMult = selfActor:getCurrentSpeed() / moveAnimSpeed;

    return speedMult
end


local animations = {
    {
        parent = nil,
        groupname = "bowandarrow1",
        condition = function(self)
            local shootHoldTime = animation.getTextKeyTime(omwself, "bowandarrow: shoot max attack")
            local currentTime = animation.getCurrentTime(omwself, "bowandarrow")

            return currentTime and math.abs(shootHoldTime - currentTime) < 0.001
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self)
            return {
                startkey = "tension start",
                stopkey = "tension end",
                loops = 999,
                forceloop = true,
                autodisable = false,
                priority = animation.PRIORITY.Weapon + 1,
                blendmask = animation.BLEND_MASK.UpperBody,
                startKey = "tension start",
                stopKey = "tension end",
                forceLoop = true,
                autoDisable = false,
                blendMask = animation.BLEND_MASK.UpperBody
            }
        end,
        startOnUpdate = true
    },
    {
        parent = "idle1h",
        groupname = "idle1hsneak",
        condition = function(self)
            return omwself.controls.sneak
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self)
            local opts = cloneAnimOptions(self.parentOptions)
            opts.loops = 999
            opts.priority = self.parentOptions.priority + 1

            return opts
        end,
        startOnUpdate = true
    },
    {
        parent = "idle1s",
        groupname = "idle1ssneak",
        condition = function(self)
            return omwself.controls.sneak
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self)
            local opts = cloneAnimOptions(self.parentOptions)
            opts.loops = 999
            opts.priority = self.parentOptions.priority + 1
            return opts
        end,
        startOnUpdate = true
    },
    {
        parent = {"idle1s","idle1ssneak"},
        groupname = "idleshield",
        condition = function()
            return gutils.isAShield(selfActor:getEquipment(types.Actor.EQUIPMENT_SLOT.CarriedLeft))
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self, pOptions)
            local opts = cloneAnimOptions(pOptions)
            opts.blendMask = animation.BLEND_MASK.LeftArm
            opts.blendmask = animation.BLEND_MASK.LeftArm

            -- Consider: will changing parent options here somehow undesirably propagate to saved self.parentOptions?
            expandPriority(pOptions)
            pOptions.priority[animation.BONE_GROUP.LeftArm] = -1

            return opts
        end,
        startOnAnimEvent = true
    },
    {
        parent = { "runforward1s", "runback1s", "runleft1s", "runright1s", "walkforward1s", "walkback1s", "walkleft1s", "walkright1s", "sneakforward1s", "sneakback1s", "sneakleft1s", "sneakright1s" },
        groupname = "runforwardshield",
        condition = function()
            return gutils.isAShield(selfActor:getEquipment(types.Actor.EQUIPMENT_SLOT.CarriedLeft))
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self, pOptions)
            local opts = cloneAnimOptions(pOptions or self.parentOptions)
            opts.blendMask = animation.BLEND_MASK.LeftArm
            opts.blendmask = animation.BLEND_MASK.LeftArm

            opts.speed = locomotionAnimSpeed()

            if pOptions then
                expandPriority(pOptions)
                pOptions.priority[animation.BONE_GROUP.LeftArm] = -1
            end

            return opts
        end,
        startOnAnimEvent = true,
        startOnUpdate = true
    },
    {
        parent = nil,
        groupname = "runbounce",
        condition = function()
            return selfActor:getCurrentSpeed() > 1 and animManager.isPlaying("weapononehand")
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self, pOptions)
            return {
                startkey = "start",
                stopkey = "stop",
                loops = 999,
                forceloop = true,
                autodisable = false,
                priority = animation.PRIORITY.Movement + 1,
                blendmask = animation.BLEND_MASK.LowerBody,
                speed = locomotionAnimSpeed()
            }
            --opts.priority[animation.BONE_GROUP.Torso] = opts.priority[animation.BONE_GROUP.Torso] + 1
        end,
        startOnUpdate = true
    },
    {
        parent = "idlebow",
        groupname = "idlebowsneak",
        condition = function(self)
            return omwself.controls.sneak
        end,
        stopCondition = function(self)
            return not self:condition()
        end,
        options = function(self)
            local opts = cloneAnimOptions(self.parentOptions)
            opts.loops = 999
            opts.priority = self.parentOptions.priority + 1
            return opts
        end,
        startOnUpdate = true
    },
    {
        parent = "weapononehand",
        groupname = "weapononehand1",
        condition = function(self)
            local startKey = self.parentOptions.startkey or self.parentOptions.startKey
            if not isAttackType(startKey) then return false end
            local counterKey = self.parent .. isAttackType(startKey)
            return attackCounters[counterKey] == 1
        end,
        options = function(self, pOptions)
            local opts = cloneAnimOptions(pOptions)

            -- Since the engine never runs 2 animations with exact same priorities - it's important to make parent animation priority unique to ensure that it will remain running in the background.
            -- Running original animations in the background is important to keep internal engine's character controller satisfied.
            uniquifyPriority(pOptions)

            pOptions.blendMask = 0
            pOptions.blendmask = 0

            return opts
        end,

        startOnAnimEvent = true
    }
}

-- Unwraping all animations that have lists as their parents
local unwrappedAnimations = {}

for _, animation in ipairs(animations) do
    if type(animation.parent) == "table" then
        for _, parent in ipairs(animation.parent) do
            local newAnimation = gutils.shallowTableCopy(animation)
            newAnimation.parent = parent
            table.insert(unwrappedAnimations, newAnimation)
        end
    else
        table.insert(unwrappedAnimations, animation)
    end
end

animations = unwrappedAnimations



I.AnimationController.addPlayBlendedAnimationHandler(function(groupname, options)
    if camera.MODE.FirstPerson ~= camera.getMode() then return end

    local startKey = options.startkey or options.startKey
    local stopKey = options.stopkey or options.stopKey
    -- print("New animation started! " .. groupname .. " : " .. startKey .. " --> " .. stopKey)

    -- Learn parent options of animations
    for _, anim in ipairs(animations) do
        if anim.parent and anim.parent == groupname then
            anim.parentOptions = cloneAnimOptions(options)
        end
    end

    -- Count attacks
    if isAttackTypeStart(startKey) then
        local key = groupname .. isAttackType(startKey)
        if not attackCounters[key] then attackCounters[key] = -1 end
        attackCounters[key] = (attackCounters[key] + 1) % 2
    end

    -- Starting override anims
    for _, anim in ipairs(animations) do
        if anim.startOnAnimEvent and anim.parent == groupname then
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


-- local cameraYaw = omwself.rotation:getYaw()
-- local viewModelYaw = omwself.rotation:getYaw()


local function onUpdate(dt)
    if camera.MODE.FirstPerson ~= camera.getMode() then return end

    -- if not animManager.isPlaying("weapononehand1") then
    --     I.AnimationController.playBlendedAnimation("weapononehand1", {
    --         startKey = "chop start",
    --         startkey = "chop start",
    --         stopKey = "chop large follow stop",
    --         stopkey = "chop large follow stop",
    --         priority = 13,
    --         speed = 2
    --     })
    -- end

    for _, anim in ipairs(animations) do
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

            shouldStart = (not anim.parent or isParentPlaying) and anim:condition()
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

    -- View inertia experiments
    --print(omwself.controls.pitchChange,omwself.rotation:getPitch())


    -- cameraYaw = cameraYaw + omwself.controls.yawChange
    -- camera.setYaw(cameraYaw)
    -- omwself.controls.yawChange = 0

    -- local newViewModelYaw = gutils.lerp(viewModelYaw, cameraYaw, 1 - 0.000001 ^ dt)
    -- if cameraYaw - newViewModelYaw > 0.2 then
    --     newViewModelYaw = cameraYaw - 0.2
    -- end
    -- local deltaModelYaw = newViewModelYaw - viewModelYaw
    -- viewModelYaw = newViewModelYaw
    -- omwself.controls.yawChange = deltaModelYaw
end


return {
    engineHandlers = {
        onUpdate = onUpdate,
    }
}
