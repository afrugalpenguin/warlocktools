local WT = WarlockTools

-- Demon summoning spells
WT.DEMONS = {
    { spellID = 688,   name = "Summon Imp" },
    { spellID = 697,   name = "Summon Voidwalker" },
    { spellID = 712,   name = "Summon Succubus" },
    { spellID = 691,   name = "Summon Felhunter" },
    { spellID = 30146, name = "Summon Felguard" },
}

-- Self-buff spells (names for FindSpellInBook lookup)
WT.BUFF_NAMES = {
    "Fel Armor",
    "Demon Armor",
    "Demon Skin",
    "Detect Invisibility",
    "Unending Breath",
    "Shadow Ward",
}

-- Group utility spells
WT.UTILITY_NAMES = {
    "Ritual of Summoning",
    "Ritual of Souls",
    "Eye of Kilrogg",
    "Sense Demons",
}

-- Stone creation spell names (for FindSpellInBook, highest rank auto-selected)
WT.STONE_NAMES = {
    "Create Healthstone",
    "Create Soulstone",
    "Create Spellstone",
    "Create Firestone",
}

-- Healthstone item IDs (all ranks + Improved Healthstone talent variants, highest first)
-- Talent tiers: Normal (0/2), Improved (1/2), Improved (2/2)
WT.HEALTHSTONE_ITEMS = {
    -- Rank 6: Master Healthstone
    22103, -- Master Healthstone (normal)
    22104, -- Master Healthstone (1/2 talent)
    22105, -- Master Healthstone (2/2 talent)
    -- Rank 5: Major Healthstone
    9421,  -- Major Healthstone (normal)
    19012, -- Major Healthstone (1/2 talent)
    19013, -- Major Healthstone (2/2 talent)
    -- Rank 4: Greater Healthstone
    5510,  -- Greater Healthstone (normal)
    19010, -- Greater Healthstone (1/2 talent)
    19011, -- Greater Healthstone (2/2 talent)
    -- Rank 3: Healthstone
    5509,  -- Healthstone (normal)
    19008, -- Healthstone (1/2 talent)
    19009, -- Healthstone (2/2 talent)
    -- Rank 2: Lesser Healthstone
    5511,  -- Lesser Healthstone (normal)
    19006, -- Lesser Healthstone (1/2 talent)
    19007, -- Lesser Healthstone (2/2 talent)
    -- Rank 1: Minor Healthstone
    5512,  -- Minor Healthstone (normal)
    19004, -- Minor Healthstone (1/2 talent)
    19005, -- Minor Healthstone (2/2 talent)
}

-- Soulstone item IDs (all ranks, highest first)
WT.SOULSTONE_ITEMS = {
    22116, -- Master Soulstone
    16896, -- Major Soulstone
    16895, -- Greater Soulstone
    16893, -- Soulstone
    16892, -- Lesser Soulstone
    5232,  -- Minor Soulstone
}

-- Spellstone item IDs (all ranks, highest first)
WT.SPELLSTONE_ITEMS = {
    22646, -- Master Spellstone
    13602, -- Greater Spellstone
    5522,  -- Spellstone
}

-- Firestone item IDs (all ranks, highest first)
WT.FIRESTONE_ITEMS = {
    22128, -- Master Firestone
    13701, -- Major Firestone
    13700, -- Greater Firestone
    13699, -- Firestone
    1254,  -- Lesser Firestone
}

-- Soul Shard item ID
WT.SOUL_SHARD = 6265

-- Build lookup set for bag scanning
WT.ITEM_TYPE_SET = {}
WT.ITEM_TYPE_SET[WT.SOUL_SHARD] = "shard"
for _, id in ipairs(WT.HEALTHSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "healthstone" end
for _, id in ipairs(WT.SOULSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "soulstone" end
for _, id in ipairs(WT.SPELLSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "spellstone" end
for _, id in ipairs(WT.FIRESTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "firestone" end
