# qb-tiretheft

FiveM QBCore tire theft script.

## Features

- Uses `qb-target` on vehicle wheels.
- Requires the `drill` item in inventory.
- Simple English minigame: press `E` when the indicator is green.
- Player carries the stolen tire as a prop.
- Tire must be placed in the vehicle trunk with `qb-target`.
- Tires show as props in the trunk.
- Player takes trunk tires one by one and sells them to the buyer with:

```lua
exports.interact:AddInteraction
```

Buyer location:

```lua
vector4(883.39, -1736.48, 32.16, 256.0)
```

Reward is `1500` cash per tire.

## Install

Add this to `server.cfg`:

```cfg
ensure qb-tiretheft
```

The `drill` item already exists in your `qb-core/shared/items.lua`.
