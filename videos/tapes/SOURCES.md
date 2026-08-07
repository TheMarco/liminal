# Tapes

Recordings played by Descent's objective and optional televisions.

All tapes are project-owner-supplied footage. `VhsTapeLibrary` discovers OGVs
in this directory. Authored `short_beginning_` and `short_random_` recordings
enter the optional pool regardless of duration; remaining recordings are split
at 30 seconds. Files explicitly reserved as non-tape game assets are retained
here but excluded from both pools. The ten mandatory long videos are fixed
sorted chapters on non-final floors 1–10. Optional random videos use a current
no-repeat cycle that persists across death, Continue, and relaunch for the
saved run.

## Objective Chapters (2026-08-06)

The ten files in `cross/` replace the previous four long recordings. Their
numbered source order is their floor order:

- `tape_02.ogv` — `cross/video1.mp4`
- `tape_03.ogv` — `cross/video2.mp4`
- `tape_04.ogv` — `cross/video3.mp4`
- `tape_05.ogv` — `cross/video4.mp4`
- `tape_43.ogv` — `cross/video5.mp4`
- `tape_44.ogv` — `cross/video6.mp4`
- `tape_45.ogv` — `cross/video7.mp4`
- `tape_46.ogv` — `cross/video8.mp4`
- `tape_47.ogv` — `cross/video9.mp4`
- `tape_48.ogv` — `cross/video10.mp4`

All converted from MP4 with `ffmpeg2theora --videoquality 7 --audioquality 3
--max_size 512x512`. Objective recordings remain duration-classified; authored
optional recordings use the `short_beginning_` and `short_random_` identities
described below. Keep every source mapping in this file.

## Current Optional VCR Pool (2026-08-07)

These 21 files replace the previous optional pool. The six `beginning` clips
play to completion in numeric order before the other fifteen enter their
random no-repeat cycle:

- `short_beginning_00.ogv` — `newshorts/beginning00.mov`
- `short_beginning_01.ogv` — `newshorts/beginning01.mov`
- `short_beginning_02.ogv` — `newshorts/beginning02.mp4`
- `short_beginning_03.ogv` — `newshorts/beginning03.mp4`
- `short_beginning_04.ogv` — `newshorts/beginning04.mp4`
- `short_beginning_05.ogv` — `newshorts/beginning05.mov`
- `short_random_00.ogv` — `newshorts/Seedance 2_5 - Static camera_Cross is writing in her notebook_I stopped naming things_At first it he.mov`
- `short_random_01.ogv` — `newshorts/Seedance 2_5 - Static camera_Cross speaks quietly_I heard footsteps following me for almost four hou.mov`
- `short_random_02.ogv` — `newshorts/Seedance 2_5 - Static camera_I counted_From the moment the elevator doors closed until they opened a.mov`
- `short_random_03.ogv` — `newshorts/Seedance 2_5 - Static camera_Several objects are piled on the table a casino chip_ a school ID card.mov`
- `short_random_04.ogv` — `newshorts/Seedance 2_5 - Static camera_The recording begins with Dr_ Cross standing beside an empty chair_ She.mov`
- `short_random_05.ogv` — `newshorts/Seedance 2_5 - Static camera_The recording begins_ Cross doesn_t speak for several seconds_There_s s.mov`
- `short_random_06.ogv` — `newshorts/Seedance 2_5 - _SEEDANCE 2 PROMPT__FORMAT  CORE INTENT_30s_ 169_ premium photorealistic sports comme.mov`
- `short_random_07.ogv` — `newshorts/random1.mp4`
- `short_random_08.ogv` — `newshorts/random2.mp4`
- `short_random_09.ogv` — `newshorts/random3.mp4`
- `short_random_10.ogv` — `newshorts/random4.mp4`
- `short_random_11.ogv` — `newshorts/random5.mp4`
- `short_random_12.ogv` — `newshorts/random6.mp4`
- `short_random_13.ogv` — `newshorts/random7.mp4`
- `short_random_14.ogv` — `newshorts/random8.mov`

## Converted Non-Tape Game Assets

These four shadow-figure clips are converted assets for other game systems.
They are explicitly excluded from `VhsTapeLibrary` and the Dr. Cross reviewer:

- `tape_06.ogv` — `magnific_a-shadowy-figure-walks-fr_0eMBEwATfW.mp4`
- `tape_07.ogv` — `magnific_a-shadowy-figure-walks-fr_u5H17S0QLD.mp4`
- `tape_08.ogv` — `magnific_a-shadowy-ghost-figure-wa_gOw4WTpSXO.mp4`
- `tape_09.ogv` — `magnific_a-shadowy-ghost-figure-wa_u5H1yxZQLD.mp4`

## Archived Previous Optional Pool — Imported Downloads (2026-08-04)

These recordings now live in
`videos/tapes/archive/legacy_optional_2026-08-07/` and are not scanned. The
original first short is archived there as well:

- `tape_01.ogv` — "dr. cross"

Converted with the documented command:
`ffmpeg2theora INPUT --videoquality 7 --audioquality 3 --max_size 512x512 -o OUTPUT`

The source files are listed in lexical basename order. The `(1)` source is
the retained copy of an exact byte-duplicate pair; the same basename without
`(1)` was excluded.

- `tape_10.ogv` — `magnific_static-camera-vhs-recordi_3z2FrUJREY.mp4`
- `tape_11.ogv` — `magnific_static-camera-vhs-recordi_O64hHbzynm.mp4`
- `tape_12.ogv` — `magnific_static-camera-vhs-recordi_YM0rUEOWeC.mp4`
- `tape_13.ogv` — `magnific_static-camera-vhs-recordi_aFE3c7UfSh.mp4`
- `tape_14.ogv` — `magnific_static-camera-vhs-recordi_cpVjyCS0eP.mp4`
- `tape_15.ogv` — `magnific_static-camera-vhs-recordi_lJUXa6Tgv9.mp4`
- `tape_16.ogv` — `magnific_static-camera-vhs-recordi_tCv9zcpmZJ.mp4`
- `tape_17.ogv` — `magnific_vhs-recording-she-adjusts_IfhPGnjtvE.mp4`
- `tape_18.ogv` — `magnific_vhs-recording-she-doesnt-_8amyT5XIrU (1).mp4`
- `tape_19.ogv` — `magnific_vhs-recording-she-folds-a_w4O8HyF7EI.mp4`
- `tape_20.ogv` — `magnific_vhs-recording-she-leans-c_fHu3XRzCDY.mp4`
- `tape_21.ogv` — `magnific_vhs-recording-she-looks-g_MBel2yvDCm.mp4`
- `tape_22.ogv` — `magnific_vhs-recording-she-looks-t_Sy7BuYtUb8.mp4`
- `tape_23.ogv` — `magnific_vhs-recording-she-looks-t_UPJo16Owny.mp4`
- `tape_24.ogv` — `magnific_vhs-recording-she-stares-_YM01Or6WeC.mp4`
- `tape_25.ogv` — `magnific_vhs-recording-she-unfolds_tCv4D39mZJ.mp4`
- `tape_26.ogv` — `magnific_vhs-recording-shes-breath_p8XSz27ehw.mp4`
- `tape_27.ogv` — `magnific_vhs-recording-shes-cleani_EbFZMTXuuO.mp4`
- `tape_28.ogv` — `magnific_vhs-recording-shes-whispe_dtowcvJXSL.mp4`
- `tape_29.ogv` — `magnific_vhs-recording-the-camera-_O64mxlnynm.mp4`
- `tape_30.ogv` — `magnific_vhs-recording-the-fluores_rgLVQHZxtc.mp4`
- `tape_31.ogv` — `magnific_vhs-recording-the-tape-be_hufNeg3vqL.mp4`

Excluded exact duplicate: `magnific_vhs-recording-she-doesnt-_8amyT5XIrU.mp4`
(byte-identical to the retained `(1)` source).

## Archived Previous Optional Pool — Additional Short Imports (2026-08-04)

All eleven source recordings are 15.09 seconds and therefore enter the
optional-TV pool. They are content-unique from one another.

- `tape_32.ogv` — `magnific_static-camera-vhs-recordi_8amiXoRIrU.mp4`
- `tape_33.ogv` — `magnific_static-camera-vhs-recordi_9ZiHOMeNYZ.mp4`
- `tape_34.ogv` — `magnific_static-camera-vhs-recordi_BhINetfoQR.mp4`
- `tape_35.ogv` — `magnific_static-camera-vhs-recordi_MBeS9yqDCm.mp4`
- `tape_36.ogv` — `magnific_static-camera-vhs-recordi_YM0xJB1WeC.mp4`
- `tape_37.ogv` — `magnific_static-camera-vhs-recordi_bxkMF0t5Y2.mp4`
- `tape_38.ogv` — `magnific_static-camera-vhs-recordi_eIB7iCAdqL.mp4`
- `tape_39.ogv` — `magnific_static-camera-vhs-recordi_fHuzhwyCDY.mp4`
- `tape_40.ogv` — `magnific_static-camera-vhs-recordi_lJUtrq1gv9.mp4`
- `tape_41.ogv` — `magnific_static-camera-vhs-recordi_u5HGV8SQLD.mp4`
- `tape_42.ogv` — `magnific_static-camera-vhs-recordi_xSsB5dDjfW.mp4`
