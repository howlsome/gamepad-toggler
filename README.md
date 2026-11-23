# GamePad Toggler

A World of Warcraft: Forever addon that remembers, per character, whether the
**Gamepad UI** (Options → Gamepad (Beta) → Enable Gamepad UI) should be on or off,
and switches it when you log in.

## Features

- Per-character Gamepad UI on/off, stored account-wide so every character is visible from any character
- Options panel (Options → AddOns → GamePad Toggler) listing all your characters with a checkbox each
- Shows full Forever names (first name and surname) in class colours, with the ruleset:
  Normal, PvP, Roleplay, Roleplay PvP or Hardcore
- Default setting for new characters
- Remove button for deleted characters
- Stays in sync if you change the setting from Blizzard's own Gamepad options

## Install

Copy the `GamePadToggler` folder into:

```
World of Warcraft/_forever_/Interface/AddOns/
```

## Commands

| Command | Action |
|---|---|
| `/gpt` | Open the options panel |
| `/gpt on` / `/gpt off` / `/gpt toggle` | Change Gamepad UI for the current character |
| `/gpt status` | Show the current character's setting and ruleset |

`/gamepadtoggler` works as an alias for `/gpt`.

## Notes

- The Gamepad UI needs a UI reload to take effect. Forever blocks addons from reloading the UI
  directly, so GamePad Toggler shows a **Reload UI** button instead (it runs `/reload` as a macro).
- When you log into a character whose setting differs from the current mode, the same reload
  prompt appears.
- Characters appear in the list after logging in once with the addon enabled.
- Setting changes wait until you leave combat.
