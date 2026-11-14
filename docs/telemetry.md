# Anonymous usage statistics

Hajánek sends a small set of anonymous usage events through
[`ol1n_telemetry`](https://github.com/lioilsources/Ol1nTelemetry) so the
owner can see what a new parent does after the first launch, whether the
tales get played to the end, how the sleep timer and the jukebox are used,
and where people give up. This file is the **event dictionary**: the
constant `hajanekDictionary` (`app/lib/core/telemetry.dart`) and this
document list exactly the same events and properties, and
`app/test/telemetry_test.dart` fails when they drift apart.

Adding an event or a property is a change to the privacy policy
(`docs/privacy.html`, `docs/PRIVACY.md`) and to the store privacy answers.
Ask the owner first.

## Rules

The rules of `ol1n_telemetry` apply unchanged: no persistent identifier (a
random session id that lives in memory), cohorts computed on the device and
sent only as bands, only enums, bands and numbers, no key → no network, the
app never waits, an offline queue of at most 500 events, off wipes the queue
at once, measuring never steers the app. See the package README.

On top of that, for Hajánek:

- **Nothing about the child.** The child's name (vocative) is never sent,
  not even whether one is set.
- **Nothing about recordings.** The parent's voice feature reports only that
  it was used (`voice_record`, `tv_pair`) and that an error was shown. No
  length, no name, no voice id, no consent text, no audio.
- **No tale id in a path.** Screens come from route patterns
  (`/tale/:id` → `tale`); the tale itself is a catalogue enum in
  `tale_play_start` only.
- Phone and TV run the same code and the same dictionary; `form` tells them
  apart.

## Configuration

| `--dart-define` | Meaning |
|---|---|
| `TELEMETRY_KEY` | Hajánek's key for the StoreMetrics collector. Empty → nothing is recorded or sent. |
| `TELEMETRY_HOST` | Collector base URL, must be `https`. Empty → nothing is recorded or sent. |
| `TELEMETRY_DEBUG` | `true` prints events to the console instead of sending them. |
| `TESTER_UNLOCK` | `true` marks the build as a tester build (`tester: true`). |

`release-android.yml` and `release-ios.yml` pass `TELEMETRY_KEY` and
`TELEMETRY_HOST` from the GitHub secrets of the same names. An absent secret
expands to an empty string and the build is silent; the settings switch is
then hidden. The key and the collector address never go into this public
repository.

## Transport and retention

Protocol v1 of `ol1n_telemetry` to the owner's own collector (StoreMetrics,
server in the EU, Czechia). Nobody else receives the events. The collector
does not store the IP address; it keeps only the country. Raw events are
kept 12 months.

## Activation

The first tale whose voice reads to the end, once per install (in the
player, when the script completes; usually with the screen locked).

## Features

Used for `feature_use` and `feature_snapshot`:

| Feature | When |
|---|---|
| `ritual_skip` | “Start now” skipped the ambient-only intro |
| `timer` | a sleep timer other than off was chosen (player or settings) |
| `jukebox` | the jukebox played on its own, without a tale |
| `mix_layers` | a layer was added in the jukebox mixer |
| `mix_save` | a mix was saved as a preset |
| `background` | a tale was given a background other than the recommended one |
| `favourite` | a tale was marked as favourite |
| `balance` | the voice ↔ background balance was changed |
| `voice_record` | a parent's voice recording was sent (only that it happened) |
| `tv_pair` | a TV was paired with a phone (on either side) |
| `lang` | the app language was changed in settings |

## Common properties

Sent with every event.

| Property | Type | Values |
|---|---|---|
| `app_version` | enum | the app version (`kAppVersion`, checked against `pubspec.yaml`) |
| `platform` | enum | `ios`, `android`, `macos`, `windows`, `linux`, `other` |
| `lang` | enum | the app's language: `cs`, `en`, `de`, `es`, `fr`, `pt-BR`, `it`, `pl`, `sk` |
| `session_band` | band | session number: `1`, `2`, `3-5`, `6-10`, `11+` |
| `days_band` | band | days since measuring began: `0`, `1`, `2-6`, `7-29`, `30+`, `pre` |
| `first_session` | bool | the very first session of a new install |
| `tester` | bool | tester build (`TESTER_UNLOCK`) or tester device |
| `form` | enum | `phone`, `tv` |

## Events

Each event says which question of the analytics plan (§1) it answers.

### `app_open`

Cold start, or a new session after more than 30 minutes in the background.
Answers: what a new user does after the first launch; do they come back
(2nd, 3rd, 6th, 11th session; day 1, 2, 7, 30).

| Property | Type | Values |
|---|---|---|
| `start` | enum | `cold`, `resume` |
| `session_band_first` | bool | the first session of this install in its `session_band` |
| `days_band_first` | bool | the first session of this install in its `days_band` |
| `campaign` | campaign | optional; QR campaign of a new install, `^[a-z0-9-]{1,24}$` |

### `screen_view`

A screen appeared. Answers: the first-session funnel, back-and-forth
between screens.

| Property | Type | Values |
|---|---|---|
| `screen` | enum | `home`, `tale`, `player`, `mixer`, `settings`, `voice`, `voice_record`, `other` |
| `prev` | enum | the previous screen, or `none` |

### `screen_leave`

A screen was left. Answers: how long people stay on which screen; screens
with a long stay and no action.

| Property | Type | Values |
|---|---|---|
| `screen` | enum | as in `screen_view` |
| `secs` | int | foreground seconds on the screen |
| `actions` | int | app events, feature uses and locked taps during the stay |

### `session_pause`

The app went to the background or is closing. Sent at once. Answers: when
and where people leave, and whether they leave with a tale or the jukebox
still playing (the usual way to fall asleep).

| Property | Type | Values |
|---|---|---|
| `active_secs` | int | foreground seconds in this session |
| `screen` | enum | the screen at the time, or `none` |
| `screen_secs` | int | foreground seconds on that screen |
| `audio` | enum | what plays: `tale`, `jukebox`, `paused` (a session is open but paused), `none` |

### `activation`

The first tale read to its end on this install. Once per install. Answers:
how many new users get the first real use, and how fast.

| Property | Type | Values |
|---|---|---|
| `secs` | int | seconds since this session's `app_open` |

### `feature_use`

The first use of a feature in a session. Answers: what advanced users use.

| Property | Type | Values |
|---|---|---|
| `feature` | enum | `ritual_skip`, `timer`, `jukebox`, `mix_layers`, `mix_save`, `background`, `favourite`, `balance`, `voice_record`, `tv_pair`, `lang` |

### `feature_snapshot`

After `app_open` of the 3rd, 6th and 11th session: which features this
install has ever used. Answers: what advanced users do not use.

| Property | Type | Values |
|---|---|---|
| `f_ritual_skip` | bool | “start now” used |
| `f_timer` | bool | sleep timer used |
| `f_jukebox` | bool | jukebox on its own used |
| `f_mix_layers` | bool | a jukebox layer added |
| `f_mix_save` | bool | a mix saved |
| `f_background` | bool | a non-recommended background chosen |
| `f_favourite` | bool | a favourite marked |
| `f_balance` | bool | the balance changed |
| `f_voice_record` | bool | a parent's voice sent |
| `f_tv_pair` | bool | a TV paired |
| `f_lang` | bool | the language changed |
| `features_used` | int | how many of them |

### `error_shown`

The user saw an error. Answers: where people struggle.

| Property | Type | Values |
|---|---|---|
| `kind` | enum | `script_load` (a tale's text could not be loaded), `voice_api` (the voice server or pairing failed), `recording` (no microphone permission or the recording failed), `tts_missing` (the device has no voice for the language; the home hint) |
| `screen` | enum | the screen at the time, or `none` |

### `tale_play_start`

A tale started in the player (phone or TV). Answers: which tales get
played, with which voice, with the ritual or not, with which timer.

| Property | Type | Values |
|---|---|---|
| `tale` | enum | catalogue id: `budulinek`, `cervena-karkulka`, `dlouhy-siroky-bystrozraky`, `hrnecku-var`, `o-smolickovi`, `pernikova-chaloupka`, `sipkova-ruzenka`, `snehurka`, `tri-prasatka`, `zlatovlaska`, `other` (a tale from a later catalogue) |
| `voice` | enum | `system` (the device's voice), `parent` (a cloned parent's voice) |
| `ritual` | bool | the “good night” ritual is on |
| `timer` | enum | sleep timer: `off`, `5`, `10`, `20`, `30`, `45`, `60` (minutes), `end_of_tale`, `other` |
| `layers` | int | background sound layers |

### `tale_play_end`

The tale's playback session ended. Answers: are tales played to the end,
how long a bedtime lasts, how often the timer or the parent cuts it off.

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok` (the ritual played out), `stop` (stopped by the parent), `timer` (the sleep timer ended it), `replaced` (another tale started), `background` (the app was in the background and never came back; written by the client), `cancel`, `error` (not used) |
| `secs` | int | foreground seconds (the screen is usually off, so this is small) |
| `voice_done` | bool | the voice read the tale to its end |
| `pct` | int | share of the script read, 0–100 |
| `mins` | int | wall-clock minutes since the start |

### `jukebox_start`

The jukebox started on its own, without a tale. Answers: is the jukebox a
reason to open the app.

| Property | Type | Values |
|---|---|---|
| `layers` | int | sound layers |

### `jukebox_end`

The jukebox session ended. Answers: how long the jukebox plays and how it
ends.

| Property | Type | Values |
|---|---|---|
| `result` | enum | `stop`, `timer`, `replaced` (a tale started), `background` (written by the client), `ok`, `cancel`, `error` (not used) |
| `secs` | int | foreground seconds |
| `mins` | int | wall-clock minutes since the start |

### `timer_set`

A sleep timer was chosen. Answers: which timer lengths people want, and
whether they set it while playing or as a default.

| Property | Type | Values |
|---|---|---|
| `timer` | enum | `off`, `5`, `10`, `20`, `30`, `45`, `60`, `end_of_tale`, `other` |
| `during` | enum | `tale`, `jukebox` (in the player while playing), `none` (in the player with nothing playing), `settings` (the default in settings) |

## Reading the data

`store-metrics report hajanek` on the collector host. Tester builds are left
out by default.
