# WarlockTools Design

A warlock utility addon for WoW TBC Anniversary Classic, adapted from the MageTools architecture.

## Architecture

Same pattern as MageTools: a global `WarlockTools` table with module registration, single event frame dispatching to modules, class-gated to `WARLOCK` on `ADDON_LOADED`.

### File Structure

```
WarlockTools.toc
Core.lua          -- Bootstrap, event dispatch, slash commands (/warlocktools, /wlt)
Data.lua          -- Spell IDs, item IDs, demon/stone/buff tables
PopupMenu.lua     -- X-layout spell popup with release-to-cast
SoulManager.lua   -- HUD (shard/stone counts) + Summon Session panel
TradeHelper.lua   -- Whisper queue, auto-target, trade distribution
Options.lua       -- Tabbed settings panel
WhatsNew.lua      -- Changelog modal
Tour.lua          -- Onboarding tour
MasqueHelper.lua  -- Masque wrapper
```

### Naming Conventions

- Saved variable: `WarlockToolsDB`
- Addon color: `|cff9482c9` (warlock purple)
- Slash commands: `/warlocktools`, `/wlt`
- Frame names prefixed with `WarlockTools` (e.g. `WarlockToolsHUD`, `WarlockToolsPopup`)

## Data Layer (Data.lua)

### Demons

Summon Imp, Summon Voidwalker, Summon Succubus, Summon Felhunter, Summon Felguard (talent only).

### Stones (Create Spells)

- Create Healthstone (Ranks 1-6)
- Create Soulstone (Ranks 1-6)
- Create Spellstone (Ranks 1-3)
- Create Firestone (Ranks 1-4)

### Self-Buffs

Demon Armor, Demon Skin (lower rank fallback), Fel Armor, Detect Invisibility, Unending Breath, Shadow Ward.

### Group Utility

Ritual of Summoning, Ritual of Souls, Eye of Kilrogg, Sense Demons.

### Tracked Items (Bag Scanning)

| Type | Items |
|---|---|
| `shard` | Soul Shard (6265) |
| `healthstone` | All ranks + talent-improved variants (different item IDs) |
| `soulstone` | All ranks |
| `spellstone` | All ranks |
| `firestone` | All ranks |

A `CONJURED_ITEM_SET` lookup maps item IDs to types, same as MageTools. Spell lookup uses `FindSpellInBook()` for highest known rank.

## SoulManager (HUD + Summon Session)

### HUD

Floating icon bar showing bag counts. Same drag, position-save, Masque support as MageTools.

| Icon | Type | Display |
|---|---|---|
| Soul Shard | `shard` | Stack count |
| Healthstone | `healthstone` | Count |
| Soulstone | `soulstone` | 0 or 1 |
| Spellstone | `spellstone` | 0 or 1 |
| Firestone | `firestone` | 0 or 1 |

Spellstone and Firestone are toggleable via an option (like MageTools' reagent toggle). All five shown by default.

Bag scanning triggers on `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, `PLAYER_ENTERING_WORLD`.

### Summon Session Panel

Shard economy view for group prep:

- Group size display (from party/raid)
- "Shards: 14"
- "Healthstones: 3 / 5 needed" (group size minus stones on hand)
- Status: "Ready!" when stocked, empty otherwise
- **Create Healthstone** secure action button

"Needed" count driven by trade queue size via `GetServingCount()`, same pattern as MageTools. Configurable `healthstonesPerPerson` setting (default 1).

## PopupMenu (X-Layout)

Same secure handler architecture as MageTools: toggle button with `SecureHandlerWrapScript`, frame ref for combat-safe show/hide.

### Quadrant Layout

| Position | Category | Spells |
|---|---|---|
| TL | Buffs | Demon Armor/Skin, Fel Armor, Detect Invisibility, Unending Breath, Shadow Ward |
| TR | Stones | Create Healthstone, Soulstone, Spellstone, Firestone |
| BL | Demons | Summon Imp, Voidwalker, Succubus, Felhunter, Felguard |
| BR | Utility | Ritual of Summoning, Ritual of Souls, Eye of Kilrogg, Sense Demons |

Category toggles in options:
```lua
popupCategories = { buffs = true, stones = true, demons = true, utility = true }
```

Only known spells shown. Felguard only appears if the player has the talent. Scanned via `FindSpellInBook()`.

No gem-delete equivalent needed (unlike MageTools' mana gem logic). Simplifies the secure handler.

Same keybind system (`SetOverrideBindingClick`), close-on-cast option, combat cleanup on `PLAYER_REGEN_ENABLED`.

## TradeHelper (Whisper Queue)

### Request Types

Two types: `healthstone` and `summon`. Can also be `both`.

### Default Whisper Keywords

| Keyword | Maps To |
|---|---|
| `healthstone` | `healthstone` |
| `hs` | `healthstone` |
| `summon` | `summon` |
| `lock` | `healthstone` |
| `warlock` | `healthstone` |

Generic keywords (`lock`, `warlock`) default to `healthstone`, same pattern as MageTools' "mage" defaulting to water. Messages matching both types become `both`.

### Queue Behavior

- Left-click row: target player + set pending trade (healthstone) or just target (summon)
- Right-click row: remove from queue
- Auto-reply: "You're queued for [request]. X ahead of you."
- Trade auto-place: finds highest-rank healthstone in bags, places in trade window
- Summon requests: target only (Ritual of Summoning is cast, not traded)
- Party chat listening toggle
- Conjure session shortcut button on queue frame opens Summon Session

## Options (Tabbed Panel)

### General Tab

- **HUD:** Show/hide, vertical/horizontal, show spellstone/firestone toggle, button size slider
- **Summon Session:** Show on login checkbox
- **Popup Menu:** Keybind capture, release-to-cast toggle, close-on-cast toggle
- **Popup Categories:** Buffs, Stones, Demons, Utility checkboxes

### Trade Helper Tab

- Auto-reply toggle
- Party chat listening toggle
- Whisper keyword editor (add/remove)
- Auto-place items in trade toggle
- Healthstones per person slider (default 1)

### Appearance Tab

- Popup button size slider
- Max queue display slider
- Session background opacity slider

Same control builders (CreateHeader, CreateCheckbox, CreateSlider, CreateKeybind, CreateKeywordEditor) and tabbed layout system as MageTools.

Blizzard Interface Options integration via `Settings.RegisterCanvasLayoutCategory` with fallback to `InterfaceOptions_AddCategory`.

## WhatsNew

Identical structure to MageTools. Warlock purple accent (`|cff9482c9`). Starts at v1.0.0 with initial release entry.

Modal overlay, scrollable changelog, "Got it!" dismiss button. `ShouldShow()` checks `lastSeenVersion` against current version.

## Tour (Onboarding)

Welcome splash + 4 guided steps with glow highlight:

1. **The HUD** -- shard and stone counts at a glance
2. **Summon Session** -- shard economy for group prep
3. **The Popup Menu** -- demons, stones, buffs, utility
4. **Options** -- customise everything

Logo: `Interface\\AddOns\\WarlockTools\\warlocktools`

Same tour version tracking, combat cancellation, ESC behavior as MageTools.

## MasqueHelper

Identical to MageTools, with `MSQ:Group("WarlockTools", name)`.

## DB Defaults

```lua
{
    hudVisible = true,
    hudX = 0,
    hudY = 0,
    hudPoint = "CENTER",
    whisperKeywords = { "healthstone", "hs", "summon", "lock", "warlock" },
    healthstonesPerPerson = 1,
    autoReply = true,
    queueVisible = true,
    hudButtonSize = 32,
    hudVertical = false,
    popupColumns = 5,
    popupCloseOnCast = true,
    autoPlaceItems = true,
    listenPartyChat = false,
    popupButtonSize = 36,
    maxQueueDisplay = 10,
    popupBgAlpha = 0.85,
    sessionBgAlpha = 0.9,
    showSessionOnLogin = false,
    popupKeybind = nil,
    hudShowExtras = true,       -- toggle spellstone/firestone on HUD
    popupReleaseMode = true,
    popupCategories = { buffs = true, stones = true, demons = true, utility = true },
}
```
