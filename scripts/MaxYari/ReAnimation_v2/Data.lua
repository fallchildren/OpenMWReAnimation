local mp = "scripts/MaxYari/ReAnimation_v2/"

local omwself = require('openmw.self')
local types = require('openmw.types')
local animation = require('openmw.animation')
local I = require('openmw.interfaces')

local animManager = require(mp .. "scripts/anim_manager")
local gutils = require(mp .. "scripts/gutils")

local attackTypes = { "chop", "slash", "thrust" }
local attackCounters = {}

local selfActor = gutils.Actor:new(omwself)

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

-- TODO duplicate code
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = true,
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
        playerOnly = false,
        condition = function(self)
            print("CHECKING CONDITION")
            local startKey = self.parentOptions.startkey or self.parentOptions.startKey
            if not isAttackType(startKey) then
                print("NOT AN ATTACK TYPE" .. startKey)
                return false
            end
            local counterKey = self.parent .. isAttackType(startKey)
            print("COUNTER KEY" .. counterKey)
            return attackCounters[counterKey] == 1
        end,
        animationHandlerThunk = function(groupname, options)
            local startKey = options.startkey or options.startKey
            -- Count attacks
            if isAttackTypeStart(startKey) then
                local key = groupname .. isAttackType(startKey)
                if not attackCounters[key] then attackCounters[key] = -1 end
                attackCounters[key] = (attackCounters[key] + 1) % 2
            end
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


for _, anim in ipairs(animations) do
    I.ReAnimation_v2.addAnimationOverwrite(anim)
end
