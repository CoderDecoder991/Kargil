# Bajrang: The Patrol

Godot 4.7.2 Compatibility-renderer first-person patrol prototype for Windows, with an optional tactical overhead command view. The first chapter is an interpretive, short test-map vertical slice about the six-man 4 JAT patrol near Bajrang in May 1999. The route, observation, weather sequence and contact are reconstructed. The documented loss is fixed and stops before captivity. This build is not a full-length or historically reviewed mission.

## Play

Open `builds/Bajrang-Patrol-Windows/Play-Bajrang.cmd` after packaging, or run `project.godot` with Godot 4.7.2. Keep the portable build folder together and writable for its first-run asset import and quick save. The game boots at 1280×720 in a window.

| Input | Action |
|---|---|
| WASD / mouse | Move / look in first person |
| Shift | Quick-step; altitude, terrain, and stamina still affect pace |
| Right mouse | Aim with a closer view |
| Left click / B / G | In first person, fire / cycle single, burst ×3 and full auto / reload |
| C / V | Crouch or rise / go prone and crawl |
| T | Switch between first person and tactical overhead view |
| Esc | Release the mouse; in overhead view, return to first person |
| Left click / Shift + left click / 1–6 / Tab | In overhead view, select or add members / select all |
| Right click | In overhead view, move selected patrol members by the shortest walkable route |
| Space / Enter | In overhead view, pause / execute queued squad orders |
| R | Start the full squad's slow crossing at the marked exposed rope anchor |
| O | Record the reconstructed observation when Lt. Kalia and the patrol are near the spur |
| Q, E / wheel | In overhead view, rotate / zoom the tactical camera |
| F1 / F2 / F3 | Performance / Balanced / High graphics |
| F5 / F9 | Quick save / quick load |

The climb prototype marks rock, scree, a snowfield, the wind-exposed shelf and a rope crossing. Reach the lower rope anchor with Lt. Kalia and press R; the objective advances after the full squad reaches the far anchor. Quick saves retain the in-progress crossing and prone stance. These sections are reconstructed for play. The route remains a short test map and does not yet meet the 20–30 minute T05 route goal. The status panel exposes ground surface, stance, stamina, cold, exposure, visibility and enemy suspicion. Prone lowers the silhouette and reduces sight/hearing, but crawling is slow; it cannot be toggled during a rope crossing. This is a generic gameplay abstraction, not a claim about the historical patrol's documented actions.

In first person, the camera follows Lt. Kalia, with the detailed textured AK model from the licensed gloved-arms asset. The five patrol members follow in formation; press T to issue individual or group movement orders in the tactical overhead view. Mouse look, quick-step, aim, crouch, prone/crawl, and G-triggered visual reload are available. The six patrol actors use a generated-character-derived 78-bone 3D rig with procedural walk, crouch/kneel, prone/crawl, rope climb, ledge traverse, cold idle, reload, contact brace and reflective aftermath poses. Reload has no ammunition simulation; the contact reaction does not represent a confirmed hit; the aftermath pose is upright and non-graphic. These procedural poses are not motion-captured clips. The rifle, gloves, clothing, likeness and exact patrol loadout are visual reconstructions, not verified historical facts. Contact remains dramatized and the documented outcome is fixed; there is no playable alternate outcome. See the art log and source ledger for provenance and uncertainty.

## Source and build status

- [Source ledger](docs/research/SOURCE_LEDGER.md)
- [Art asset log](docs/research/ART_ASSET_LOG.md)
- [Mission dossier](docs/research/Kargil_Mission_1_Bajrang_Patrol_Research_and_Plan.md)
- [Current A–Z status](docs/research/ISOMETRIC_A-Z_STATUS.md)

The previous first-person and Unreal prototypes are preserved separately at `H:\Kargil-FPS-Archive-2026-10-23` and are not part of this project.
