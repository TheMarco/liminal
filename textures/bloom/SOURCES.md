# The Bloom texture sources

All maps in this directory come from [Poly Haven](https://polyhaven.com/) and
are released under [CC0](https://polyhaven.com/license). Attribution is not
required, but provenance is retained here.

- `leather_red_02_*_1k.jpg` — [Leather Red 02](https://polyhaven.com/a/leather_red_02)
  by Rob Tuytel; 1K JPG color, OpenGL normal, and roughness maps. The game
  recolors and world-triplanar-projects the wrinkled hide as wet organic tissue.
- `mud_forest_*_1k.jpg` — [Mud Forest](https://polyhaven.com/a/mud_forest)
  by eye-candy.xyz; 1K JPG diffuse, OpenGL normal, and roughness maps. The game
  darkens it and adds a restrained clearcoat as the Bloom's wet substrate.

Image content is unchanged from Poly Haven. Runtime materials supply tint,
projection scale, reflectivity, and animated vascular emission.

## TextureCan — Others 0001

The `cellular_flesh/others_0001_*_2k` maps are the seamless
[Bloody Organ, Intestine or Flesh Texture (Others 0001)](https://www.texturecan.com/details/137/)
from [TextureCan](https://www.texturecan.com/). TextureCan releases its PBR
textures under [CC0 1.0](https://www.texturecan.com/terms/).

- Included maps: base color, ambient occlusion, roughness, height, DirectX
  normal and OpenGL normal, at 2K.
- Runtime use: the OpenGL normal, color, roughness and AO maps form the Bloom's
  procedural incubator sacs, hanging cysts and membranes; color and roughness
  also drive the animated black vascular shader used on vines and roots.
- Modification: source pixels are unchanged. Godot applies triplanar mapping,
  a dark bruise tint, wet clearcoat and restrained animated emission. The
  DirectX normal and height maps remain in the provenance set but are not bound
  by the current Godot materials.
