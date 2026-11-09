# Game localization

## Implemented languages and content

The language picker in Settings offers English, Japanese, Korean, Simplified
Chinese and Traditional Chinese. It applies immediately, persists in settings,
and survives Reset defaults. A new profile uses the OS language when supported.
Choosing a non-English language enables dialogue subtitles; the player can turn
them off afterward. Existing profiles without a language field also get captions
when first opened on a supported non-English system.

The five catalogs in `localization/` contain 1,517 source entries each, covering
menus, controls, gameplay prompts, photo captions, environmental writing, credits,
and video-effect controls (including the original NTSC/CRT schemas). Latin product
names, creator names and technical identifiers intentionally remain recognizable.
Dynamic messages retain their original game/save values and translate for display.

`subtitles/{en,ja,ko,zh_CN,zh_TW}.json` contain the same 402 timed cues across 35
runtime track entries: 401 dialogue cues and the intro's Evelyn Cross license
caption. Silent tracks are explicitly empty. The current Dr. Cross recordings and
camera tutorial are covered; archived superseded recordings and the four reserved
shadow-animation clips are not part of the spoken runtime library. The videos and
English voice performances themselves have not been re-encoded or dubbed.

All four regional Noto Sans CJK faces are bundled, with their OFL license. They
serve as fallbacks for the game's existing fonts. Menus and subtitles remain at
window resolution. For CJK, `readable_game_text.gd` mirrors gameplay Labels above
the tape effects so fine strokes survive low signal resolutions; English retains
the recorded HUD. Camera feedback uses a Label so it follows the same rule.

The 63 authored posters, nine painted storefront signs and the mall directory
have translated readings when viewed up close. This preserves their original
artwork. `world_text_reader.gd` checks the facing direction and line of sight, and
hides readings during modal gameplay. Authored brand names remain on the art.

## Editing and adding text

Edit the JSON catalogs directly in UTF-8. English source text is the key; add the
same key to every locale. Translate complete sentences, keeping the order and type
of `%s`, `%d` and other format tokens. Do not replace input bindings, file paths,
shader IDs or save values with translations. New drawn text must use
`Localization.text()`. Standard Controls and Label3D use Godot's translation flow.
Avoid assembling a sentence from untranslated fragments after translating it.

`game_translation.gd` handles already-formatted HUD templates, uppercase source
variants, remapped interaction keys and multiline text. It bounds its runtime
cache. For custom world lettering sized from font metrics, use
`Localization.max_text_width()` to allow switching language without rebuilding
geometry. Add baked inscriptions to `localization/art_text.json`, their translations
to every catalog, and a `LocalizedArt.mark()` marker on the readable face.

Subtitle times use `VideoStreamPlayer.stream_position`. Language changes select
the corresponding track without restarting playback. Keep track paths, cue order,
and timing aligned across all five files. A missing catalog falls back to English;
the audit fails incomplete delivered catalogs rather than accepting the fallback.

## Verification on 2026-10-24

Passed: localization catalog parity, format tokens, CJK glyph coverage, settings
persistence, default subtitle behavior, live Label/Label3D translation, remapped
prompts, multiline inscriptions, line-of-sight occlusion, 1280×720 and 800×600 menu
bounds, modal HUD visibility, camera-feedback translation, and restoration of the
English HUD. Existing settings, title, subtitle, mall-sign and photo-framing audits
also pass. Subtitle checks include live switching during playback.
Native GPU UI checks pass in English and Japanese, including mouse/keyboard input
and scene/UI separation. Japanese gameplay, title, Instructions and all four
language settings screens were visually inspected. The native harness reports existing CRT image-load
warnings and texture cleanup warnings; it exits successfully.

Relevant checks (after the normal Godot import):

```
godot --headless --path . --script tools/audit_localization.gd
godot --headless --path . --script tools/audit_story_subtitles.gd
godot --headless --path . --script tools/audit_game_settings.gd
godot --path . --script tools/audit_screen_ui.gd -- --nologo --language=ja
```

`audit_localization.gd -- --capture-localization` can also save native settings
captures to `/tmp/liminal-settings-<locale>.png`. Run it with a native renderer for
captures. Version **0.5.7** has been exported for Windows, Linux and macOS. All
three exported packs passed `tools/verify_release_pack.sh` from outside the source
project, including every catalog, subtitle track, CJK font and the font license.
All 167 release audit gates are satisfied by the full run and focused reruns after
fixing compact pause-menu, photo-feedback and save-warning layouts. The localization
audit now checks those layouts in all five languages. The world-hash baseline was
updated for the localized inscription markers; excluding only those markers
reproduced the previous baseline exactly. Release evidence is under
`build/steam-release-2026-10-24/`. Apple accepted the Mac app on October 25 via
submission `15e3eed2-8cbb-40fd-a134-a289b7989d33`. Its Developer ID signature,
stapled ticket and Gatekeeper checks pass, and the notarized game pack is
byte-identical to the verified export. The Steam upload completed on October 25,
2026 as [Build 26204961](https://partner.steamgames.com/apps/builddetails/4336360/26204961),
with all three platform depots confirmed in Steamworks. It was activated on the
default branch on October 25 at 4:12 p.m. Pacific. Store revision 6 was published
the same day; the public store confirms interface and subtitles for English,
Japanese, Korean, Simplified Chinese and Traditional Chinese, with full audio
only in English.

## Remaining release work

These are authored translation drafts, not a claim of native-speaker certification.
Before advertising complete language support, review terminology and tone with
native speakers and play the full Descent and Wander flows in each language.
Check every recording's reading speed against its speech; some inherited English
cue durations are short. Check photos, subtitles, all graphics presets, laptop and
Deck resolutions, and text inside incidental third-party prop artwork. The known
posters/signs are accessible through translated readings; arbitrary lettering in
imported textures has not all been repainted.

Steam text sources and publication status are in
[`localization/steam/README.md`](localization/steam/README.md). Language support was published with the verified localized build. Store screenshots and trailer
text/subtitles need their own media pass.
