class_name SpatialTransitionPlan
extends RefCounted
## One validated site transition: expected topology revision, before/after
## phases, every intermediate edge set, connectivity requirements, and the
## presentation mode. Built by the director, executed by the transaction.


var site_id := ""
var expected_revision := 0
var from_phase := ""
var to_phase := ""
## Phase name -> {canonical edge key -> open}. Covers from, to, and every
## intermediate phase the transaction may settle.
var phase_edges := {}
## Phase name -> Array of [cell, cell] pairs that must stay mutually
## reachable in that phase. Each phase proves its own occupiable set:
## a cell cut off in every phase is a broken plan, but B's room is
## legitimately unreachable while only A is open.
var phase_pairs := {}
## Aperture name -> {"cell": Vector2i, "dir": int} grid mapping.
var aperture_edges := {}
var witness_id := ""
## "lit" or "blackout". Same physical transition; only presentation differs.
var presentation := "lit"
var hold_timeout := 6.0


func is_valid() -> bool:
	if site_id.is_empty() or from_phase.is_empty() \
			or to_phase.is_empty():
		return false
	if not phase_edges.has(from_phase) \
			or not phase_edges.has(to_phase):
		return false
	if presentation != "lit" and presentation != "blackout":
		return false
	return hold_timeout > 0.0
