# HOW TO DO ANIMATION
- each entity has a selected animation animation and frame
- on update, the animation is advanced


1. Each visual type gets an animation enum
2. Global animation enum


# UI
Current bug: when selecting a tile occupied by a player, the attack menu gets created. When clicking on a button, the attack menu "moves" because it's created again at the point of the mouse click.

Therefore, mouse clicks should only register on the "top" layer that they happened.

Could have a global flag that marks the consumption of the mouse click, but this would require ordering the button checks.

Ordering would be
Settigns menu
Attack Menu
Map

uhh that's it?

i guess we don't have many clickable ui elements

### Attack menu behavior
- if you click on a player
  - spawn the attack menu
- if you click elsewhere
  - despawn the attack menu
