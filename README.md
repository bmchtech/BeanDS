
# BeanDS
WIP DS Emulator written in D. Can boot a handful of games, though not many actually go in-game yet. I'm trying to keep the codebase clean as well.

## Demo Videos (turn audio up, but warning that the audio sounds awful)

https://user-images.githubusercontent.com/15221993/190197736-8e903641-1c51-485e-b66e-fa5b85205e76.mp4


## Usage
`./beands --help` for a guide on how to use this emulator.
You will need copies of the BIOSes as well as the firmware, and these need to be stored in the `roms` folder at the same directory as the emulator. The BIOSes and firmware can be dumped from a DS. 

## Build

`dub build --compiler ldc2 -B release`
I recommend compiling in release mode, as you will need all the speed you can get.

## Planned Features

Currently I'm working on booting the firmware. Other plans include proper audio (see demo video), proper 3D graphics support, support for additional savetypes besides EEPROM, and a JIT to help alleviate my speed issues. 


## Special Thanks
+ Martin Korth, for [GBATek](https://problemkaputt.de/gbatek.htm#dsmemorymaps), which is an excellent source of documentation on the GBA, DS, and 3DS.
+ [Arisotura](https://github.com/Arisotura/), for [GBATek Addendum and Errata](https://melonds.kuribo64.net/board/thread.php?id=13), which expands on the knowledge provided in GBATek. Also, [her articles](https://melonds.kuribo64.net/comments.php?id=85) on the 3D GPU are extremely helpful.
+ [RockPolish](https://github.com/RockPolish), for creating the excellent [Rockwrestler test suite](https://github.com/RockPolish/rockwrestler)
+ [PSI](https://github.com/PSI-Rockin) for creating an [article on the 3D GPU's interpolation](https://corgids.wordpress.com/2017/09/27/interpolation/)
+ [Powerlated](https://github.com/powerlated), for creating a [test rom](https://github.com/Powerlated/amogus.nds) for testing audio
+ [StrikerX3](https://github.com/StrikerX3/), [fleroviux](https://github.com/fleroviux/), [PSI](https://github.com/PSI-Rockin), [Kelpsy](https://github.com/Kelpsy/), [Dillon](https://github.com/Dillonb), and [Ace314159](https://github.com/Ace314159) for answering my questions on the Emudev discord server.
