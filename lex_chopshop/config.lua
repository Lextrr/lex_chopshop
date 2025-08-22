Config = {}

-- Debug mode
Config.Debug = true

-- Job settings
Config.RequireJob = false
Config.AllowedJobs = {'mechanic', 'criminal'}

-- Cooldown in seconds
Config.Cooldown = 900 -- 15 minutes

-- Vehicle settings
Config.AllowedVehicleClasses = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12}
Config.MinVehicleValue = 5000
Config.ChopTime = 30 -- seconds

-- Chop shop locations
Config.ChopShops = {
    {
        id = 1,
        label = 'Sandy Shores Chop Shop',
        coords = vector3(2341.83, 3049.52, 48.15),
        radius = 10.0,
        blip = {
            enabled = true,
            sprite = 446,
            color = 1,
            scale = 0.7,
            label = 'Chop Shop'
        }
    },
    {
        id = 2,
        label = 'Docks Chop Shop',
        coords = vector3(1198.37, -3253.24, 7.09),
        radius = 10.0,
        blip = {
            enabled = true,
            sprite = 446,
            color = 1,
            scale = 0.7,
            label = 'Chop Shop'
        }
    }
}

-- Rewards
Config.Rewards = {
    common = {
        chance = 85,
        items = {
            {item = 'chop_door', amount = {2, 2}},
            {item = 'chop_hood', amount = {1, 1}},
            {item = 'chop_wheels1', amount = {4, 4}}
        }
    },
    uncommon = {
        chance = 10,
        items = {
            {item = 'chop_seats', amount = {1, 2}},
            {item = 'chop_alternator', amount = {1, 1}},
            {item = 'chop_radiator', amount = {1, 1}}
        }
    },
    rare = {
        chance = 5,
        items = {
            {item = 'chop_engine', amount = {1, 1}},
            {item = 'chop_wheels2', amount = {4, 4}}
        }
    }
}