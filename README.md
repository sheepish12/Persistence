# Persistence
Persistence is a simple and lightweight wrapper over ProfileService. It supports a limited subset of ProfileService's features (you can only get, set, and listen to data changing with it). The module simply caches profiles and allows multiple scripts to access their data. It is easy to install and use:

1. Get the latest version of Persistence from the [Releases](https://github.com/BenSBk/Persistence/releases) page.
2. Add the ProfileService dependency from the Roblox library [asset](https://www.roblox.com/library/5331689994/ProfileService).
3. Put both inside ServerStorage or similar and change the path to ProfileService inside Persistence.
4. Add a script inside ServerScriptService that initialises the module and registers and deregisters players. This script is where you will choose the data template and profile store name:
```lua
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Persistence = require(ServerStorage.Modules.Persistence)

local STORE_NAME = "player-data-live"
local TEMPLATE = {
  ["cash"] = 0,
  ["items"] = {},
  ["log-in-times"] = 0,
}

Persistence.init(STORE_NAME, TEMPLATE)

Players.PlayerAdded:Connect(Persistence.register)
Players.PlayerRemoving:Connect(Persistence.deregister)
-- We do this so Studio works and to be future-proof.
for _, player in ipairs(Players:GetPlayers()) do
  task.spawn(Persistence.register, player)
end
```

From there, you can use the module from any server-side code however you like. It gives you four functions to work with.

---

`Persistence.await` gets the value belonging to the field you pass and returns it. If the player's profile hasn't loaded yet, **the function yields** until it's available.
```lua
local cash = Persistence.await(player, "cash")
print(player.Name .. " has " .. tostring(cash) .. " cash!")
```

---

`Persistence.get` attempts to get the value belonging to the field you pass and returns one or two values. If the profile is loaded when the function is called, it returns `true` and the value belonging to the field. If the profile isn't loaded when the function is called, it returns `false`.
```lua
local isLoaded, cash = Persistence.await(player, "cash")
if isLoaded then
  print(player.Name .. " has " .. tostring(cash) .. " cash!")
end
```

---

`Persistence.set` sets the value belonging to the field you pass. Even if the profile isn't loaded yet, this function will still work; the set request will just be queued until it is.
```lua
Persistence.set(player, "cash", 0)
```

---

`Persistence.bindToChange` allows you to listen to changes in values across all players for a specific field.
```lua
Persistence.bindToChange("cash", function(player, cash)
  print(player.Name .. " has " .. tostring(cash) .. " cash!")
end)
```

---

That's all. All values you get from and give to Persistence are deep copied, so if a value is a table and you edit the table from `get`, the actual table won't change. The only way to change values is to set them. To clarify once again: the only function out of these four that yields is `Persistence.await`.

If you have a question feel free to use GitHub [Discussions](https://github.com/BenSBk/Persistence/discussions).
