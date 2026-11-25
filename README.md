# Junk Drop (DaylightUI Plugin)

Bags full in the middle of a quest? Press one key and the cheapest junk stack in your bags is
gone. Press again for the next one.

Needs [Daylight UI](https://www.curseforge.com/wow/addons/daylightui). Made for WoW: Forever.

## Setup

1. Install it next to Daylight UI.
2. Esc > Options > Keybindings > **Daylight UI** > **Drop cheapest junk**, and pick a key.

`/dui dropjunk` or `/dropjunk` does the same as the key.

Rather click than press a key? `/dui` > Plugins > Junk Drop > **Make macro** (or type
`/dropjunk macro`) makes a **Junk Drop** macro and puts it on your cursor. Click an action bar slot
to place it. Each click of it deletes one stack.

## What it deletes

Each press deletes **one stack**: the one worth least (its sell price times how many are in it).

- Gray items count as junk.
- Items you marked as junk in Daylight UI's bags (Alt-right-click > Sell as junk) count too.
  You can switch that off.
- Items you put on your own **junk lists** count too, whatever their color or price (see below).
- Only stacks worth **10 silver or less** go. Pricier junk is left for a vendor. Change the cap in
  `/dui` > Plugins > Junk Drop, or set it to 0 for no cap.

It never deletes:

- items on your Ignored list,
- items you locked in Daylight UI's bags,
- items in an equipment set while Daylight UI's "lock sets" option is on,
- anything during a fight, or while your cursor is holding an item.

Each delete says what went, and what it was worth, in chat. Turn on **Ask before deleting** for a
yes/no box first.

## Your junk lists

There are two lists: one for the character you're on, and one shared by all your characters.
Junk Drop reads both, so an item on either one counts as junk.

Edit them in `/dui` > Plugins > Junk Drop > **Your junk lists**:

- **White items in your bags** that sell to a vendor are listed cheapest first (all stacks of an
  item added up; the Hearthstone and other no-value items are left out). Click
  **Add** to put one on this character's list, or **For all** for every character.
- Or drop any item in the box at the top (or type its name or item ID, or shift-click it in while
  the box is selected), then click **Add** or **For all**.
- Each list shows its items with their sell price. **Share** moves an item to the list for all
  characters, **Only here** moves it back, and **Remove** takes it off.

- **Ignore** (in the bag list or next to the box) puts an item on the **Ignored** list, shared by
  all characters. Ignored items are left out of the bag list and Junk Drop never deletes them,
  even gray ones. **Unignore** takes it off again. On a wide options window the Ignored list sits
  beside the bag list.

An item sits on one list at a time. The list for all characters already covers this one, and
adding an ignored item to a junk list stops ignoring it.

Or in chat, where `<item>` is an item shift-clicked into the chat line, its name (if it's in your
bags), its item ID, or nothing to use the item on your cursor:

- `/dropjunk add <item>` puts it on this character's list.
- `/dropjunk addall <item>` puts it on the list for all characters.
- `/dropjunk ignore <item>` ignores it.
- `/dropjunk remove <item>` takes it off every list (and stops ignoring it).
- `/dropjunk list` shows your lists.
- `/dropjunk clear` empties this character's list, `/dropjunk clearall` the shared one,
  `/dropjunk clearignored` the ignored one.

Listed items skip the silver cap: they go whatever they're worth, still cheapest first. Locked
items are never deleted, even when listed.

## Credits

The idea of a "destroy next junk item" key comes from
[Dejunk](https://github.com/moody/Dejunk) by moody. Junk Drop is its own code, written for
Daylight UI.
