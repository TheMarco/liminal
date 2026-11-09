# Supplied elevator

`Elevator.glb` is the unchanged, self-contained model supplied by Marco from
`Elevator_Game_Asset` on 2026-10-07. Its materials and six textures are embedded.
The accompanying asset and collision manifests are copied from that package.
The source package describes the geometry/textures as procedurally authored,
with no third-party model or stock texture. No separate license was supplied.

The game uses `scripts/elevator_car.gd` and the existing `Chunk` lift lifecycle
for Wander, Descent objectives, arrival cars, and the final exit. The package's
standalone demo/controller is not used. Travel, tape requirements, waiting,
sound, arrival retirement and obstruction reversal remain owned by the game.

The model stays at metre scale. A half-turn and Z=2.56m translation put its back
against the generated wall and its entrance toward the room; an 8mm vertical
offset prevents the room floor from showing through the cabin tiles. Four
physics door bodies use the supplied travel distances and collision dimensions
(door depth includes the visible edge trim). The supplied indicator housing
contains the live floor/wait text in place of its fixed caret.
