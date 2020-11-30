# Character Realism

By: CloneTrooper1019
Made for Roblox!

## What is this?

*Realism* is a character enhancement system for Roblox designed to be adaptive and minimally invasive to existing game code. It allows players to see their avatar's body in first person and look around with their head in third person. It additionally override's Roblox's default walking sound with a set of material-based walking sounds. 

## Features

- Compatible with real-time avatar scaling and HumanoidDescription changes.
- Interpolated 100% on the client, no snapping or lag.
- Supports both R6 and R15 avatars.

## Installation

This repository is setup as a [Rojo](https://rojo.space/) project! Syncing the `default.project.json` file of this project with your Studio session will automatically set it up. 

Alternatively, you can drag and drop the `Realism.rbxm` file distributed in this project's [Releases](https://github.com/CloneTrooper1019/Character-Realism/releases) page into your game. Just make sure the `RealismServer` and `RealismClient` scripts are placed in their appropriate locations so they only execute once upon the game starting. I recommend placing `RealismServer` into the `ServerScriptService`, and `RealismClient` under `StarterPlayer/StarterPlayerScripts`!

## Licensing

*Realism* is licensed under v2.0 of the Mozilla Public License. The intent of using this license is to allow the system to be used commercially in Roblox games for free without requiring the entire source code of the game to be disclosed. However, any improvements that you make to the system itself which could benefit others using it should be publicly disclosed under the same conditions. You must also provide credit to me (CloneTrooper1019) somewhere in your game if you use this system. This can be either the description or an in-game credits feature. Whatever suits you best :)!