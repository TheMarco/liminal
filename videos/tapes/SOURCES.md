# Tapes

Recordings played by Descent's objective and optional televisions.

All tapes are project-owner-supplied footage. `VhsTapeLibrary` discovers every
OGV in this directory and splits it by duration: recordings of 30 seconds or
longer play in elevator objective rooms; shorter recordings play in scattered
optional sets. Mandatory long videos are fixed sorted chapters on non-final
floors 1–10. Only four long assets currently exist, so chapters 5–10 repeat
deterministically until six more files are added. Optional short videos use a
current no-repeat cycle that persists across death, Continue, and relaunch for
the saved run.

- `tape_01.ogv` — "dr. cross"
- `tape_02.ogv` — "doctor2"
- `tape_03.ogv` — "cross3"
- `tape_04.ogv` — "nvideo"
- `tape_05.ogv` — "scottclean"

All converted from MP4 with `ffmpeg2theora --videoquality 7 --audioquality 3
--max_size 512x512`. A newly converted OGV enters the appropriate duration
pool automatically; keep its source mapping in this file.

## Imported Downloads (2026-08-04)

Converted with the documented command:
`ffmpeg2theora INPUT --videoquality 7 --audioquality 3 --max_size 512x512 -o OUTPUT`

The source files are listed in lexical basename order. The `(1)` source is
the retained copy of an exact byte-duplicate pair; the same basename without
`(1)` was excluded.

- `tape_06.ogv` — `magnific_a-shadowy-figure-walks-fr_0eMBEwATfW.mp4`
- `tape_07.ogv` — `magnific_a-shadowy-figure-walks-fr_u5H17S0QLD.mp4`
- `tape_08.ogv` — `magnific_a-shadowy-ghost-figure-wa_gOw4WTpSXO.mp4`
- `tape_09.ogv` — `magnific_a-shadowy-ghost-figure-wa_u5H1yxZQLD.mp4`
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

## Additional Short Imports (2026-08-04)

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
