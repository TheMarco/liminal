# Story subtitles

`en.json` contains dialogue cues keyed by the exact runtime movie path.
The overlay reads `VideoStreamPlayer.stream_position`; it does not advance a
second timer. Rewind, replay, pausing and interrupted tapes retain the video's
timing. Captions appear above the tape effects, below the settings menu.

The tracks cover the camera tutorial, ten objective chapters and twenty
spoken optional recordings. The prologue and the non-verbal inserted
`short_random_06` clip have explicit empty tracks. Captions describe spoken
dialogue, not a complete sound-effects caption track.

Timing was extracted locally from the shipped OGV audio using
faster-whisper / small.en word timestamps on 2026-09-26. Objective text was
compared with `docs/TAPE_SCRIPTS.md`; delivery differs slightly from the
scripts. Cues retain the recorded delivery, with punctuation and obvious
homophone corrections. Source audio/video has not been changed.

Keep cues ordered and non-overlapping, at most two lines, with end times
inside the movie. Update this file when replacing a recording. The subtitle
audit checks coverage, timing bounds, rewind behavior and settings; the pack
verifier checks that exported recordings include their tracks. Listening
review in the fresh-player session remains useful for ambiguous words and
reading comfort.
