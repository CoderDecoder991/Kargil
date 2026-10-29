# Third-party notices

The six patrol actors use the generated-character-derived 78-bone 3D rig and a simple original AK-pattern prop. The first-person view uses the textured AK model and adapted gloved support arms from `assets/hands/gloved_hands_trimmed.glb`, described below. The models, gloves and weapon are visual reconstructions, not verified likeness, uniform, gloves or loadout. The previous DanlyVostok and BAMEN-derived models remain unused source/fallback assets; their licenses are retained below for provenance.

The project includes the gloves and weapon described below in the current first-person build.

The portable Windows prototype includes the official Godot Engine 4.7.2 executable from the [Godot Windows download](https://godotengine.org/download/windows/). Godot Engine is licensed under the MIT license. Its copyright and full license notice are included as `GODOT_LICENSE.txt` in the portable build. The project scripts, terrain meshes, and synthesized wind and rifle placeholders were made for this prototype.

The eight footstep WAV files are processed field recordings released under CC0:

- `snow_step_1.wav`–`snow_step_4.wav`: [4 dry snow steps](https://opengameart.org/content/4-dry-snow-steps), recorded by Iwan Gabovitch (qubodup), CC0.
- `gravel_step_1.wav`–`gravel_step_4.wav`: four recordings from [42 Snow and Gravel Footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps), recorded by Corsica_S, CC0.

The source FLAC recordings were high-pass filtered at 80 Hz, loudness adjusted, and converted to mono 44.1 kHz PCM with `scripts/prepare_footsteps.ps1`. The WAV files are distributed with the game; the source archives and extracted FLAC files remain in ignored `tools/sound_sources/` for local preparation. No attribution is legally required by CC0, but it is included here for provenance.

The first-person AK-47 weapon reports in `assets/audio/weapons/` are cut from real AK-47 (7.62×39) range recordings in [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), released under CC0. These sounds were created and recorded by Ben Jaszczak, Brian Nelson, Kevin Heras, and Matthew Nanney. Source files are `AK-47/C_28P.wav` (single shots), `AK-47/C_29P.wav` (short bursts) and `AK-47/C_27P.wav` (long bursts), all near the shooter, from the prepared library; `tools/extract_ak_sounds.py` resamples them from 24-bit 96 kHz to 16-bit 48 kHz stereo and cuts single-shot, three-round burst, seamless full-auto loop, automatic-round, last-round and echo-tail clips. The recordings are a civilian range AK-47, not a verified 1999 patrol weapon or Kargil acoustics.

The first-person glove and textured AK model in `assets/hands/gloved_hands_trimmed.glb` are adapted from [cktang88/3d-fps](https://github.com/cktang88/3d-fps), which credits [“Fps arms” by bumstrum (DJMaesen)](https://sketchfab.com/3d-models/fps-arms-9452ce4cddde4110a4fd73e555a8e412) and [“FPS AK-74m animations” by ccransh](https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14) under CC BY 4.0. For this prototype the source glTF compression was decoded and dequantized; the weapon's original textured geometry is displayed with its stock and spare magazine hidden in the first-person camera, and the support glove is aligned to the model's authored GripL marker. The asset does not establish the actual patrol's gloves or weapon. [CC BY 4.0 license](https://creativecommons.org/licenses/by/4.0/).

The nine runtime character cutouts in `assets/Characters/` (`patrol_armed_v1.png`–`patrol_armed_v5.png` and `opposing_armed_v1.png`–`opposing_armed_v4.png`) are AI-generated concept art created for this project. They are dramatized figures, not historical photographs, verified uniforms, or likenesses of named people. The older user-provided concept portraits remain in source but are not included in the runtime portable build.

Historical sources and their limitations are listed in the two research files in this folder. Those sources do not grant permission to use personal likenesses, archival imagery, or quotations in a public release.

