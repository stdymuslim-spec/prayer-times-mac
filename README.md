# Prayer Times for Mac

A tiny menu bar app for Singapore's daily prayer times. It counts down to the next prayer and notifies you
10 minutes before and at each prayer time.

- **Menu bar countdown:** shows the next prayer, for example `Asar in 1h 12m`. Click it for today's full timetable.
- **Two notifications per prayer** for Subuh, Zohor, Asar, Maghrib and Isyak:
  - **"10 minutes to Asar"**, with a soft chime
  - **"It's time for Asar."**, with the call to prayer
- **Silent mode** for pop-ups without sound, and **Pause** to stop notifications completely.
- **Starts at login** automatically. You can turn that off from the menu.
- **Lightweight:** about 1 MB, no Dock icon, no windows, no network access, and no data collected.

Syuruk (sunrise) is shown in the timetable but doesn't trigger notifications. Clicking a notification stops its sound.

## Requirements

- macOS 14 Sonoma or later, on Apple Silicon or Intel
- Apple's free Command Line Tools

No Apple Developer account is needed. You build the app on your own Mac, so macOS doesn't show "unidentified
developer" warnings.

## Install

1. Install the Command Line Tools, if you don't have them already:

   ```bash
   xcode-select --install
   ```

2. Download the project and build it:

   ```bash
   git clone https://github.com/stdymuslim-spec/prayer-times-mac.git
   ```

   ```bash
   cd prayer-times-mac && ./build.sh
   ```

`build.sh` compiles the app, installs it to `~/Applications/Prayer Times.app`, and opens it.

On first launch:

- Click **Allow** when macOS asks to show notifications.
- The app adds itself to your login items, so it starts again after a restart. Untick **Launch at Login** in its
  menu to stop that.

Look for the moon icon in your menu bar, then use **Test 10-Minute Reminder** and **Test Prayer Time** in its menu
to check both notifications.

## Updating

To get the latest version, run this from the project folder:

```bash
git pull && ./build.sh
```

### Next year's timetable

The included timetable covers **1 January to 31 December 2026**. The menu warns you two weeks before it runs out.
To add a new year:

1. Download the new yearly timetable PDF from the official Singapore prayer timetable source.
2. Install `pdftotext`, which the converter uses:

   ```bash
   brew install poppler
   ```

3. Convert the PDF and rebuild:

   ```bash
   tools/parse_timetable.py ~/Downloads/"Prayer timetable 2027.pdf" && ./build.sh
   ```

The converter checks every day of the year and merges the new times into `Resources/timetable.json`.

## Customising

- **Sounds:** replace `Resources/reminder.mp3` (the 10-minute chime) or `Resources/call_to_prayer.mp3`, then run
  `./build.sh`. Keep each file short. If a file is missing, the app uses a built-in macOS sound instead.
- **Other cities:** `Resources/timetable.json` maps each date to its prayer times:

  ```json
  "2026-09-15": { "Subuh": "05:40", "Syuruk": "06:57", "Zohor": "13:01", "Asar": "16:03", "Maghrib": "19:04", "Isyak": "20:13" }
  ```

  Replace it with your own times in the same format. Then change the `singapore` time zone near the top of
  `Sources/main.swift` to yours and rebuild.

## Good to know

- **The app must be running.** It checks at the start of every minute and shows notifications itself, so nothing
  appears if you quit it.
- **Sleep:** if your Mac is asleep at prayer time, that notification is skipped. It isn't played late.
- **Focus:** sounds still play when a Focus is on. Use **Silent** when you need quiet.

## Uninstall

1. Untick **Launch at Login** in the app's menu.
2. Choose **Quit Prayer Times**.
3. Delete `~/Applications/Prayer Times.app`.

## Project layout

| Path | What it is |
|---|---|
| `Sources/main.swift` | The whole app |
| `Resources/timetable.json` | Prayer times by date (Singapore time) |
| `Resources/*.mp3` | Notification sounds |
| `tools/parse_timetable.py` | Converts a yearly timetable PDF to JSON |
| `tools/make_icon.swift` | Draws the app icon |
| `build.sh` | Builds, signs, installs and launches the app |

## Credits

- **Prayer times:** the official
  [2026 Singapore prayer timetable](https://isomer-user-content.by.gov.sg/48/f989baef-c5eb-440e-b3bb-874626a0664e/Prayer%20timetable%202026.pdf)
  (gov.sg).
- **Reminder sound:** "Notification 11" by soundreality on [Pixabay](https://pixabay.com/).
- **Call to prayer:** from [Zedge](https://www.zedge.net/).

The sound files belong to their creators and aren't covered by this project's license.

## License

The code is released under the [MIT License](LICENSE).
