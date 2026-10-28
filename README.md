# Meridian

A small, native macOS meeting planner for people spread across time zones. Lay out a day hour
by hour for every place you work with, see who is working, nearly working or asleep, and catch
daylight-saving changes before they move a meeting.

## Download

Get `Meridian-<version>.zip` from [Releases](https://github.com/ckarwoski/Meridian/releases),
unzip it and move `Meridian.app` to Applications. It's signed and notarized, and needs macOS 26
or later.

## Using it

- **Add places:** Add Place (⌘N) searches cities through Apple Maps, or time zones by name or
  abbreviation (`Tokyo`, `Pacific`, `UTC`). A city is kept with its coordinates, so the grid can
  show daylight under each hour.
- **Read the grid:** one row per place, one column per hour of the shown day in the reference
  place's time. Green is working hours, yellow is within two hours of them, and dark is outside.
  The bottom row shows the hours that suit everyone.
- **Compare an hour:** click a cell to see that moment in every place, then Copy (⇧⌘C) to paste
  the times into an invite. Esc clears it.
- **Edit a place:** click its name to set working hours, add a note, make it the reference, or
  remove it. Places can be sorted west to east or arranged by hand.
- **Change the day:** ⌘← / ⌘→ for a day, ⇧⌘← / ⇧⌘→ for a week, ⌘T for today, or the date picker.
- **Clock changes:** an orange line marks a daylight-saving change on the grid (dashed when an
  hour is skipped). Changes coming up within the chosen window (1 week to 3 months) are listed
  under the grid. When an hour happens twice, both cells show their zone, e.g. `1:30a MDT` and
  `1:30a MST`.
- **Menu bar:** Meridian also lives in the menu bar for a quick look. Turn this off in
  Settings (⌘,), along with 24-hour time and the daylight strip.

## Build

Requires Xcode 26 and macOS 26. Open `Meridian.xcodeproj` and run the Meridian scheme; ⌘U runs
the tests.

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
`Sources` and `Tests` are synced folders, so new files there show up without regenerating; run
`xcodegen generate` after changing `project.yml` or adding files under `Resources`. The app icon
is an Icon Composer bundle whose layer shapes come from `scripts/make-icon.swift`.

To make a copy that runs on other Macs, choose Product → Archive, then Distribute App → Direct
Distribution. Xcode signs it with a Developer ID certificate and notarizes it. Set your own team
in `project.yml` (`DEVELOPMENT_TEAM`) first.

## License

MIT. See [LICENSE](LICENSE).
