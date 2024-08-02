# ReAnimation - first-person - v2: Rogue
An immersive reimagining of (some) of the TES3: Morrowind 1st-person animations. Developed for OpenMW engine.

v2: Rogue includes: 
- All ReAnimation first-person v1 animations.
- Locomotion animations for 1h weapons and bows.
- Separate set of animations for shortswords/daggers.
- Separate sets of animations for sneaking with 1h weapons, daggers and bows.
- Alternating attack animations for 1h weapons.
- Other smaller niceties.

![1h walk](/imgs/demo_1h.gif)
![Dagger walk](/imgs/demo_dagger.gif)
![Bow walk and shoot](/imgs/demo_bow.gif)
![Alternating attacks](/imgs/demo_1h_attacks.gif)

Note: Gifs are fairly low fps, it looks even better in-game.

## How to install

- Download this repository as an archive and install using Mod Organizer 2. Or manually place the contents of this repository into your ".../Morrowind/Data Files" folder. 
- Enable the mod's .omwscript file in "Content Files" tab of the OpenMW launcher.

Have fun!

## Mod compatibility

Compatible with practically any other animation mod. ReAnimation uses OpenMW system of animation overrides and will only override a specific set of animations. Recommended to use with [MCAR](https://www.nexusmods.com/morrowind/mods/48628) for delightfull swimming and casting animations, but will work just fine without it.

[Better Bodies](https://www.nexusmods.com/morrowind/mods/48387) - causes a left-shoulder's sharp polygon to protrude on the left side of the screen while having naked arms (as well as with some common shirts) and sneaking with a dagger. Most noticeable with a [Low First Person Sneak Mode](https://www.nexusmods.com/morrowind/mods/43108). This is most likely an issue on the side of Better Bodies. Until it's fixed - simply wear a peace of armor on your left shoulder that doesn't bug out.

## Vanilla/MWSE compatibility

Not currently compatible. If you would like to port the scripting part to MWSE - please do, I'm not familiar with MWSE and am not planning to change that.
However please keep this mod as a dependency, instead of reuploading the whole thing.

## Appreciation

My thanks go to OpenMW discord community for massively helping me overcome a multitude of Lua hurdles, testing and providing feedback.






