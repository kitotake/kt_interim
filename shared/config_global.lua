Config = {}


Config.Locale = 'fr'
Config.UseOxTarget = true
Config.Notification = 'ox_lib' -- ox_lib, esx, qb, etc.
Config.ProgressBar = 'ox_lib' -- ox_lib, esx, qb, etc.


Config.ShowBlips = true
Config.BlipSprite = 408
Config.BlipColor = 5
Config.BlipScale = 0.8

Config.Jobs = {
    construction = {
        enabled = true,
        label = "Ouvrier de construction",
        description = "Collectez et déposez des briques sur le chantier avec un véhicule",
        salary = 150, 
        blip = {
            coords = vector3(1090.82, -2255.53, 31.22),
            sprite = 478,
            color = 47,
            scale = 0.8
        },
        npc = {
            coords = vector4(1092.499, -2253.792, 30.233, 266.46), 
            model = 's_m_y_construct_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        vehicleSpawn = {
            coords = vector4(1092.79, -2262.30, 30.26, 90.0),
            model = 'burrito3',
            plate = 'INTERIM'
        },
        collectPoint = {
            coords = vector3(1022.06, 2517.37, 45.520),
            marker = true,
            markerType = 1,
            markerColor = {r = 255, g = 165, b = 0}
        },
        depositPoint = {
            coords = vector3(1387.86, -768.86, 66.42),
            marker = true,
            markerType = 1,
            markerColor = {r = 0, g = 255, b = 0}
        },
        item = {
            name = 'construction_brick',
            label = 'Brique de construction',
            amount = 5,
            required = true
        },
        rewards = {
            type = 'money',
            amount = 150
        },
        animation = {
            collect = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 3000
            },
            deposit = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 2000
            }
        }
    },

    cleaning = {
        enabled = true,
        label = "Agent d'entretien",
        description = "Collectez les poubelles et déposez-les à la déchetterie",
        salary = 120,
        blip = {
            coords = vector3(-323.81, -1545.86, 31.02),
            sprite = 318,
            color = 2,
            scale = 0.8
        },
        npc = {
            coords = vector4(-322.24, -1546.02, 30.02, 280.0),
            model = 's_m_m_janitor',
            scenario = 'WORLD_HUMAN_JANITOR'
        },
        collectPoints = {
            {coords = vector3(-305.72, -1530.24, 27.72), marker = true},
            {coords = vector3(-318.29, -1524.43, 27.72), marker = true},
            {coords = vector3(-332.15, -1537.19, 27.72), marker = true}
        },
        depositPoint = {
            coords = vector3(-349.85, -1569.17, 25.23),
            marker = true,
            markerType = 1,
            markerColor = {r = 0, g = 255, b = 0}
        },
        item = {
            name = 'trash_bag',
            label = 'Sac poubelle',
            amount = 5,
            required = true
        },
        rewards = {
            type = 'money',
            amount = 120
        },
        animation = {
            collect = {
                dict = 'missfbi4prepp1',
                anim = '_idle_garbage_man',
                duration = 4000
            },
            deposit = {
                dict = 'missfbi4prepp1',
                anim = '_idle_garbage_man',
                duration = 2500
            }
        }
    },

    delivery = {
        enabled = true,
        label = "Livreur de colis",
        description = "Collectez et livrez des colis en ville",
        salary = 180,
        blip = {
            coords = vector3(78.93, 112.46, 81.17),
            sprite = 478,
            color = 17,
            scale = 0.8
        },
        npc = {
            coords = vector4(78.93, 112.46, 80.19, 160.0),
            model = 's_m_m_ups_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        collectPoint = {
            coords = vector3(91.28, 93.43, 78.72),
            marker = true,
            markerType = 1,
            markerColor = {r = 255, g = 165, b = 0}
        },
        deliveryPoints = {
            {coords = vector3(285.28, -585.44, 43.29)},
            {coords = vector3(-265.45, -957.28, 31.22)},
            {coords = vector3(1138.28, -469.88, 66.73)},
            {coords = vector3(-1193.28, -891.28, 13.98)},
            {coords = vector3(373.82, -1812.28, 29.09)}
        },
        item = {
            name = 'delivery_package',
            label = 'Colis',
            amount = 1,
            required = true
        },
        rewards = {
            type = 'money',
            amount = 180
        },
        animation = {
            collect = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 2500
            },
            delivery = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 2000
            }
        }
    },

    shop_logistics = {
        enabled = true,
        label = "Logisticien magasin",
        description = "Déplacez des cartons dans l'entrepôt",
        salary = 140,
        blip = {
            coords = vector3(992.28, -3097.82, -38.99),
            sprite = 478,
            color = 5,
            scale = 0.8
        },
        npc = {
            coords = vector4(2685.56, 3515.36, 52.35, 85.0),
            model = 's_m_m_postal_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        collectPoint = {
            coords = vector3(1001.28, -3102.45, -39.99),
            marker = true,
            markerType = 1,
            markerColor = {r = 255, g = 165, b = 0}
        },
        depositPoint = {
            coords = vector3(1015.72, -3110.28, -38.99),
            marker = true,
            markerType = 1,
            markerColor = {r = 0, g = 255, b = 0}
        },
        item = {
            name = 'shop_box',
            label = 'Carton de marchandise',
            amount = 8,
            required = true
        },
        rewards = {
            type = 'money',
            amount = 140
        },
        animation = {
            collect = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 2000
            },
            deposit = {
                dict = 'anim@heists@box_carry@',
                anim = 'idle',
                duration = 1500
            }
        }
    },

    taxi = {
        enabled = true,
        label = "Chauffeur de taxi",
        description = "Transportez des clients à travers la ville",
        salary = 200,
        blip = {
            coords = vector3(895.28, -179.28, 74.70),
            sprite = 198,
            color = 5,
            scale = 0.8
        },
        npc = {
            coords = vector4(895.28, -179.28, 73.70, 240.0),
            model = 's_m_m_gentransport',
            scenario = 'WORLD_HUMAN_STAND_MOBILE'
        },
        vehicleSpawn = {
            coords = vector4(906.82, -177.28, 73.88, 240.0),
            model = 'taxi',
            plate = 'INTERIM'
        },
        pickupPoints = {
            {coords = vector3(127.28, -1045.28, 29.28), label = "Centre-ville"},
            {coords = vector3(-1037.28, -2735.82, 20.17), label = "Aéroport"},
            {coords = vector3(1138.28, -469.88, 66.73), label = "Mirror Park"},
            {coords = vector3(-1193.28, -891.28, 13.98), label = "Vespucci"},
            {coords = vector3(373.82, -1812.28, 29.09), label = "Grove Street"}
        },
        destinationPoints = {
            {coords = vector3(-265.45, -957.28, 31.22), label = "Mission Row"},
            {coords = vector3(1138.28, -469.88, 66.73), label = "Mirror Park"},
            {coords = vector3(285.28, -585.44, 43.29), label = "Pillbox Hill"},
            {coords = vector3(-1037.28, -2735.82, 20.17), label = "Aéroport"},
            {coords = vector3(373.82, -1812.28, 29.09), label = "Grove Street"}
        },
        rewards = {
            type = 'money',
            baseAmount = 100,
            perMeterRate = 0.05
        },
        npcPassenger = {
            models = {'a_m_m_business_01', 'a_f_m_business_02', 'a_m_y_business_01', 'a_f_y_business_01'}
        }
    },

    trucker = {
        enabled = true,
        label = "Chauffeur poids lourd",
        description = "Transportez des marchandises par camion",
        salary = 250,
        blip = {
            coords = vector3(1240.28, -3239.82, 7.09),
            sprite = 477,
            color = 17,
            scale = 0.8
        },
        npc = {
            coords = vector4(1240.28, -3238.42, 5.09, 270.0),
            model = 's_m_m_trucker_01',
            scenario = 'WORLD_HUMAN_HANG_OUT_STREET'
        },
        vehicleSpawn = {
            coords = vector4(1251.28, -3242.28, 5.88, 270.0),
            model = 'phantom',
            trailer = 'trailers2',
            plate = 'INTERIM'
        },
        collectPoint = {
            coords = vector3(1202.33, -3239.22, 6.02),
            marker = true,
            markerType = 1,
            markerColor = {r = 255, g = 165, b = 0}
        },
        depositPoints = {
            {coords = vector3(992.28, -3097.82, -38.99), label = "Entrepôt sud"},
            {coords = vector3(1201.28, -1335.82, 35.22), label = "Entrepôt nord"},
            {coords = vector3(-1078.28, -2827.82, 27.70), label = "Entrepôt aéroport"}
        },
        item = {
            name = 'truck_crate',
            label = 'Caisse de marchandise',
            amount = 15,
            required = true
        },
        rewards = {
            type = 'money',
            amount = 250
        }
    }
}

Config.ItemsToAdd = {
    construction_brick = {
        label = 'Brique de construction',
        weight = 500,
        stack = true,
        close = true,
        description = 'Une brique de construction lourde'
    },
    trash_bag = {
        label = 'Sac poubelle',
        weight = 200,
        stack = true,
        close = true,
        description = 'Un sac poubelle à déposer'
    },
    delivery_package = {
        label = 'Colis',
        weight = 300,
        stack = true,
        close = true,
        description = 'Un colis à livrer'
    },
    shop_box = {
        label = 'Carton de marchandise',
        weight = 400,
        stack = true,
        close = true,
        description = 'Un carton de marchandise'
    },
    truck_crate = {
        label = 'Caisse de marchandise',
        weight = 800,
        stack = true,
        close = true,
        description = 'Une grosse caisse de marchandise'
    }
}