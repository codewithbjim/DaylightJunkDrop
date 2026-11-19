# Junk Drop (DaylightUI Plugin)

Bags full in the middle of a quest? Press one key and the cheapest junk stack in your bags is
gone. Press again for the next one.

Needs [Daylight UI](https://www.curseforge.com/wow/addons/daylightui). Made for WoW: Forever.

## Setup

1. Install it next to Daylight UI.
2. Esc > Options > Keybindings > **Daylight UI** > **Drop cheapest junk**, and pick a key.

`/dui dropjunk` or `/dropjunk` does the same as the key.

## What it deletes

Each press deletes **one stack**: the one worth least (its sell price times how many are in it).

- Gray items count as junk.
- Items you marked as junk in Daylight UI's bags (Alt-right-click > Sell as junk) count too.
  You can switch that off.
- Only stacks worth **10 silver or less** go. Pricier junk is left for a vendor. Change the cap in
  `/dui` > Plugins > Junk Drop, or set it to 0 for no cap.

It never deletes:

- items you locked in Daylight UI's bags,
- items in an equipment set while Daylight UI's "lock sets" option is on,
- anything during a fight, or while your cursor is holding an item.

Each delete says what went, and what it was worth, in chat. Turn on **Ask before deleting** for a
yes/no box first.

## Credits

The idea of a "destroy next junk item" key comes from
[Dejunk](https://github.com/moody/Dejunk) by moody. Junk Drop is its own code, written for
Daylight UI.
