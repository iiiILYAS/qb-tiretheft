Config = {}

Config.RequiredItem = 'drill'
Config.RewardPerTire = 1500
Config.MoneyAccount = 'cash'
Config.MaxTiresPerVehicle = 4

Config.TargetDistance = 1.8
Config.TrunkDistance = 2.0

Config.BlacklistedVehicleClasses = {
    [8] = true,  -- motorcycles
    [13] = true, -- cycles
    [14] = true, -- boats
    [15] = true, -- helicopters
    [16] = true, -- planes
    [21] = true, -- trains
}

Config.Models = {
    Tire = 'prop_wheel_tyre',
    Drill = 'prop_tool_drill',
    AxleStand = 'imp_prop_axel_stand_01a',
    CarJack = 'imp_prop_car_jack_01a',
    Buyer = 's_m_m_autoshop_01'
}

Config.Buyer = {
    coords = vector4(883.39, -1736.48, 32.16, 256.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    distance = 4.0,
    interactDst = 2.0,
    blip = {
        enabled = false,
        sprite = 642,
        color = 5,
        scale = 0.75,
        label = 'Tire Buyer'
    }
}

Config.Minigame = {
    rounds = 3,
    greenWindow = 750,
    failTime = 2600,
    text = 'Press E on GREEN',
    hubOffset = vector3(0.0, 0.0, 0.02)
}

Config.TheftScene = {
    useWheelHud = true,
    showJacks = true,
    drillAtWheel = true,
    drillOffset = vector3(0.0, 0.0, -0.10),
    drillRot = vector3(90.0, 0.0, 0.0),
    sideDistance = 0.72,
    axleStandOffset = vector3(0.0, 0.0, -0.78),
    jackOffset = vector3(0.0, 0.48, -0.82),
    groundLift = 0.02
}

Config.TheftCamera = {
    enabled = true,
    sideDistance = 1.35,
    frontBackOffset = 0.12,
    heightOffset = 0.18,
    lookAtOffset = vector3(0.0, 0.0, 0.02),
    fov = 33.0,
    easeIn = 650,
    easeOut = 450
}

Config.Progress = {
    placeInTrunk = 1800,
    takeFromTrunk = 1600,
    sell = 1800
}

Config.WheelBones = {
    'wheel_lf',
    'wheel_rf',
    'wheel_lm1',
    'wheel_rm1',
    'wheel_lm2',
    'wheel_rm2',
    'wheel_lm3',
    'wheel_rm3',
    'wheel_lr',
    'wheel_rr'
}

Config.WheelIndexes = {
    wheel_lf = 0,
    wheel_rf = 1,
    wheel_lm1 = 2,
    wheel_rm1 = 3,
    wheel_lm2 = 45,
    wheel_rm2 = 47,
    wheel_lm3 = 46,
    wheel_rm3 = 48,
    wheel_lr = 4,
    wheel_rr = 5
}

Config.TrunkBones = {
    'boot',
    'boot_dummy'
}

Config.Carry = {
    bone = 57005,
    pos = vector3(0.17, 0.04, -0.04),
    rot = vector3(-90.0, 0.0, 15.0),
    animDict = 'anim@heists@box_carry@',
    anim = 'idle'
}

Config.Drill = {
    bone = 57005,
    pos = vector3(0.12, 0.02, -0.03),
    rot = vector3(90.0, 180.0, 20.0),
    animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
    anim = 'machinic_loop_mechandplayer'
}

Config.TrunkTireOffsets = {
    { pos = vector3(-0.32, -2.15, 0.55), rot = vector3(0.0, 90.0, 0.0) },
    { pos = vector3(0.32, -2.15, 0.55), rot = vector3(0.0, 90.0, 0.0) },
    { pos = vector3(-0.18, -2.52, 0.55), rot = vector3(0.0, 90.0, 0.0) },
    { pos = vector3(0.18, -2.52, 0.55), rot = vector3(0.0, 90.0, 0.0) }
}
