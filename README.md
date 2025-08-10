# avnav-editor
Map editor software for AVNav: Stormworks self-driving system.

Uses [Godot engine](https://godotengine.org/). (Surprisingly great for apps!)

Sawyer: https://steamcommunity.com/sharedfiles/filedetails/?id=2687216009
Arid: https://steamcommunity.com/sharedfiles/filedetails/?id=3276833115

Build requires Godot 4.2+. At this time, releases built with (and tested on) Godot 4.2 only.

## Notes
* Obviously, some features (such as the Inspector and HTTP service) were never finished! (sorry)
* Items marked by \* in the export menu have tooltips. Hover over them to read more.
* After exporting, add the data into your AVNav microcontroller using XML editing. (hint: save the microcontroller locally, open the XML, and Ctrl+F "Node data" - then replace each numbered property with the corresponding <4096 char. line) (repeat for way data)
* The included high-resolution backdrop map is universal for Sawyer and Arid. It is trivial to replace it with your own for a world with a custom seed (e.g. for mapping cross-continental railways, the Arctic, and other islands). The map bounds can be modified in the Godot 'Project Settings.'

If you used this software to produce an AVNav map, please give credit!
