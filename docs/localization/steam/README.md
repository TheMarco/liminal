# Steam localization — app 4336360

These translations were saved as Steamworks drafts on 2026-10-24. On 2026-10-25, the public Japanese, Korean, Simplified Chinese and Traditional Chinese pages were verified outside beta mode, including translated descriptions and AI/mature-content disclosures. Build **26204961 (0.5.7)** is live on the default branch. Store revision **6** was published on October 25 at 4:12 p.m. Pacific with interface and subtitle support for all five languages; full audio remains English.
Each language JSON contains
`short_description`, `about_html`, equivalent `about_bbcode` for the Steamworks
editor, all six Early Access answers, AI disclosure, mature-content description,
and the published Windows/macOS/Linux requirements.

- `en.json`: source snapshot, 2026-10-24.
- `ja.json`: Japanese / Steam `japanese`.
- `ko.json`: Korean / Steam `koreana`.
- `zh_CN.json`: Simplified Chinese / Steam `schinese`.
- `zh_TW.json`: Traditional Chinese / Steam `tchinese`.

The initial description and requirements were read from
[the game's Steam page](https://store.steampowered.com/app/4336360/) through its public
app-details response. All text was subsequently checked against the current
Steamworks localization export and Content Survey. The Early Access duration was
updated in these files to match the current estimate of three to five months;
the other Early Access answers and both disclosures matched the prepared source.
The introduction's explicit AI-use notice
and the separate AI disclosure have both been translated, without changing their
meaning. The game title and product/hardware names remain unchanged.

All four short descriptions are below 300 characters. HTML structure and field
coverage match English. Native-language editorial review remains outstanding.
The existing Linux requirement says **15 GB RAM**, while Windows says **16 GB**;
these drafts preserve the published numbers rather than silently changing them.

## Saved drafts and verification

`steamworks-import.json` uses Steamworks' downloaded JSON schema and contains only
the four requested target languages. It saved 17 fields per language: long and
short descriptions, six Early Access answers, and nine system-requirement text
fields. A fresh export matched all 68 imported values; English and all other
languages were preserved exactly. All four description previews were inspected.

The four AI disclosures and four mature-content descriptions were saved in a
separate Content Survey draft copied from the published answers. After reloading,
all eight translations and both English originals matched. Survey classifications
and published ratings were preserved. There are 76 translated fields saved in total.

The initial October 24 save used no publication controls. The translated store
copy and disclosures were subsequently verified on the public storefront. On
October 25, revision 6 published the language-support flags plus whitespace-only
normalization in the existing translations. The public language table was checked
after publication. The [store editor](https://partner.steamgames.com/admin/game/edit/1075424/?activetab=tab_publish)
and [Content Survey](https://partner.steamgames.com/contentsurvey/edit/4336360/)
remain the administrative sources.

Interface and subtitles are now marked for all five languages alongside the
localized live build; full audio remains English. Steam treats store
localization and in-game support separately:
[Steamworks localization documentation](https://partner.steamgames.com/doc/store/localization).

The language JSON files remain review packages; `steamworks-import.json` is the
actual validated Steam import payload. Existing
capsules retain the English brand title. Localized screenshots and any text or
speech in promotional trailers still need a media pass before calling the entire
store presence finished. Those assets should come from the release-tested build.
