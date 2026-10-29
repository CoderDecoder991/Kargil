# A05l — production character base mesh brief

**Status:** Started 23 October 2026; BAMEN candidate remains opt-in after technical import pass.

## Goal

Replace the interim `assets/models/soldier_tac_danlyvostok_ccby.glb` with a production-ready, fully rigged Indian Army soldier base that reads clearly from the fixed isometric camera and remains respectful and generic where the historical record is uncertain.

## Acceptance requirements

- Full human anatomy with believable hands, feet, face, helmet and clothing volume.
- Clean topology suitable for a game-resolution mesh and at least one lower-detail LOD.
- One consistent humanoid skeleton with named hand, arm, spine, head, leg and foot bones.
- Neutral, low-ready, rifle-ready, crouch, climb and prone-compatible poses without inverted limbs.
- Enough facial and clothing shape to read from close zoom, three-quarter, side and rear views.
- No floating headset, intersecting major parts, detached hands, visible rig artifacts or front-facing cutout dependence.
- Materials can be replaced independently in A05m; the mesh must not depend on the current field-weave texture.
- License and provenance recorded in `THIRD_PARTY.md` before the asset enters the runtime build.
- Historical boundary recorded in `ART_ASSET_LOG.md` and `SOURCE_LEDGER.md`: the model is a generic reconstruction, not a likeness of Lt. Kalia or a claim about verified 1999 kit.

## Current audit

The workspace contains the credited DanlyVostok tactical-suit GLB and the downloaded CC BY 4.0 BAMEN candidate. The BAMEN candidate passes the technical validator with one mesh, one skeleton, 78 bones and humanoid scale. Its candidate-only shoulder pose and rifle transform now pass the runtime two-hand threshold: measured hand-to-contact distances are approximately 0.082 m left and 0.090 m right, below the 0.11 m check. It remains opt-in until close, side, rear, crouch and contact captures pass. The candidate is also contemporary armored art, so it cannot be treated as period-informed Kargil clothing without a separate kit pass. The attempted world-positioned detail overlay was removed after close capture exposed floating gear; future details must be bone-attached or skinned.

## Review captures required before integration

The packaged candidate smoke run completed with the Compatibility renderer at 1280×720 Performance settings and measured 50.0 average FPS, 40.4 FPS fifth percentile and 31.5 FPS minimum in the contact scene. The capture confirms the candidate loads in the six-person scene, but the current camera framing is still too distant for the required production close review.

The review camera now scales its physical isometric offset with zoom, so close zoom brings the camera toward the selected figure instead of only shrinking the orthographic view. Source and packaged input checks still pass after this change. The packaged busiest-scene measurements at 1280×720 on the GT 730 after conservative renderer scaling and bounded directional shadow distance are Performance 45.5 average / 37.4 fifth percentile / 30.3 minimum FPS, Balanced 33.7 / 28.7 / 20.0, and High 31.5 / 28.5 / 20.5. Performance clears the 30 FPS minimum in this run; stronger presets remain open optimization work.

The dedicated candidate review harness now produces clean close captures: `builds/a05l_candidate_review.png`, `builds/a05l_candidate_side.png`, and `builds/a05l_candidate_crouch.png`. Named Mixamo leg and spine bones replaced fixed indices in the gait code, so the candidate's crouch bends at the hips and knees without finger distortion. The front and crouch captures show readable anatomy and a two-hand rifle pose. The side capture still needs a cleaner unobstructed ground setup, and the modern armor, visor helmet and equipment remain unsuitable as period-informed Kargil kit without a separate art pass.

1. Neutral standing, front three-quarter, side and rear.
2. Close zoom showing face, hands, helmet, seams and boot construction.
3. Rifle-ready pose with both hands contacting the INSAS reconstruction.
4. Crouch, climb and rope-traverse poses.
5. Six-person contact scene at Performance, Balanced and High presets.

## Next action

Retarget the candidate with a measured two-hand rifle pose, then review the candidate's modern armor and helmet against a period-informed kit brief. Do not make it default or delete the interim GLB until the replacement passes the captures and the packaged input check.

## Candidate gate

Run the candidate through the project validator before integration:

```powershell
& .\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/validate_character_base.gd -- assets/models/candidate.glb
```

The validator requires a Node3D scene with mesh geometry, a humanoid-scale bounding box, and a skeleton with at least 20 bones. Passing this gate is only a technical import check; it does not establish historical clothing, likeness, licensing, or production visual quality.
