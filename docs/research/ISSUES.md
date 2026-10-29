# Mission 1 issue and decision log

## Resolved

- Mouse look did not respond in the playable build because the full-screen HUD consumed mouse motion before the player controller's unhandled-input callback. The controller now reads motion in `_input` while the cursor is captured. A viewport-injected mouse test verified horizontal and vertical camera movement in the real Godot window; the portable build was rebuilt with the fix.
- Snow walking used a short generated noise burst that sounded artificial and was cut off when replayed. It now uses four recorded dry-snow steps and four recorded snow-covered gravel steps with varied playback, overlapping voices, and no footsteps while airborne. The recordings are CC0; see `THIRD_PARTY.md`.
- A fresh portable folder could not load WAV files because Godot's asset import cache had not been created. `Play-Mission1.cmd` now runs a headless first-launch import; a clean-copy launcher test loaded and played the new clips.
- The cairns were small dark boxes and the next one was hard to find. All five are now visible stacked-stone landmarks with amber cloth, 3D labels, collision, and a distance/direction HUD cue. A gameplay screenshot and route smoke test verified the first cairn and interactions.
- Camera bob previously used a separate distance oscillation from the footstep sounds and could drift or feel out of rhythm. Camera height, lateral sway, and slight roll now use the same alternating stride counter as the recorded footfalls. `C` gives a steady view for motion comfort; a walking smoke test verified left/right sway, audio count, and settling.
- Snow footsteps were slightly loud relative to gravel. Their playback range is now 2 dB lower; the gravel range is unchanged.
- The fifth cairn previously advanced directly to a short contact beat. It now starts a playable dramatized exchange with generic opposing high positions, return fire, rock cover, exposure pressure, and brief position suppression from aimed player fire. A full-route smoke test and GT 730 contact benchmark passed.
- The climb between shelter and reconnaissance was a continuous ridge without a distinct traversal action. A reconstructed exposed shelf now has a visible rope, an E anchor interaction, slower crossing, limited lateral drift, and a required far-anchor completion before observation. Route automation and a GT 730 screenshot verified the prototype.
- The reconnaissance note disappeared after its HUD timer. The J route journal now retains the fictional observation alongside a schematic stop map and next-landmark distance. A route smoke test and GT 730 screenshot verified the panel and its close behavior.
- The final contact had no actual damage, recovery, impact cue, or accessible difficulty choice, and its original rocks did not reliably screen the spread of high positions. Larger player-side rocks now provide majority-screened cover; condition damage has directional feedback and recovers after holding cover; rock hits flash; and Standard/Assisted contact presets change accuracy, cadence, hit spacing, and recovery. A focused encounter test found a safe cover position and verified the feedback loop. Human fairness review is still open.

## Open

- Verify dedicated GT 730 memory. WMI reports 4,293,918,720 bytes, a value close to the 32-bit field limit; this is not trusted as actual VRAM.
- Obtain an authorized 4 JAT account or archive to resolve the 14/15 May patrol date and the June handover date discrepancy before recording final historical narration.
- Verify five sepoys' name spellings and any rank changes against an official memorial record.
- Obtain licensed regional elevation references and verify the Bajrang spur silhouette. Current terrain is handmade and deliberately not sold as a survey of the route.
- Source and review the specific period clothing, weapons, climbing kit, shelter, and animation. A05a–c replace the capsule figures and generic player prop with more detailed original patrol forms, an INSAS interpretation, softened original fabric, first-person aim/reload motion, and restrained rope hardware. The INSAS is a period-possible visual choice, not verified patrol kit. Close screenshots still show stylized meshes. Production-quality character/weapon surfaces and animation, human playtesting, and historical/sensitivity review remain; see `ART_REFERENCE_AND_UNCERTAINTY.md`. Replace synthesized wind and rifle sounds; playtest and refine the recorded footsteps on terrain.
- Add accessibility controls for remapping, mouse sensitivity, FOV, subtitles, contrast, weather strength, and motion comfort.
- Add authored squad behavior, save/load, script review, and a full physical-route playtest. The encounter has a first fairness-systems pass, but still needs human testing and reviewed period art/audio.
- Playtest the new shelf on foot, tune the rope width and movement comfort, and expand the climb with terrain reference. The rope obstacle is a game construction, not evidence of this patrol's gear or exact route.
- Make a conventional Godot Windows export with official export templates and test on a clean Windows machine.

## Decisions, 20 October 2026

- Started in Godot 4.7.2 with the Compatibility renderer after a real OpenGL 3.3 boot on the GT 730.
- Built a procedural approximately 620 m approach with about 118 m of nominal elevation gain. The exact 1999 path remains unknown.
- The prototype encounter always ends with a fixed memorial card and sourced context; no playable captivity or torture appears.
- Rifle and ammunition values are temporary gameplay placeholders, not a claim about the patrol's actual loadout.
- The five companions travel in formation without teleporting. Their new generic figures and gait remain prototype dramatization, not a reenactment of individual actions.

