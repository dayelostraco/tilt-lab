# TODO

Running task list. Milestones follow the project brief. Substantive work is
also tracked in the Linear project
[**Tilt Lab**](https://linear.app/sigilark/project/tilt-lab-1a7e761ac64a)
(SigilArk team).

| Milestone | Linear |
|---|---|
| 1 Project bootstrap | [SIG-45](https://linear.app/sigilark/issue/SIG-45) |
| 2 Physics and lower playfield | [SIG-46](https://linear.app/sigilark/issue/SIG-46) |
| 3 Repeatable ball feeder | [SIG-47](https://linear.app/sigilark/issue/SIG-47) |
| 4 Drop catch MVP (V0.1) | [SIG-48](https://linear.app/sigilark/issue/SIG-48) |

## Milestone 1: project bootstrap

- [x] Inspect the local environment for VPX tooling and reference tables
- [x] Establish a source-controlled VPX workflow (`vpxtool` extract/assemble)
- [x] Verify extract/assemble is lossless for the base table
- [x] Choose and record the base table (`blankTable.vpx`, sha256 pinned)
- [x] Split the base script into tracked modules under `scripts/`
- [x] Build pipeline (`tools/build.sh`) and editor re-import (`tools/import.sh`)
- [x] Static script checker (`tools/check.py`), negative-tested
- [x] Debug and structured-logging core
- [x] Trainer key hooks that do not disturb standard bindings
- [x] VR-navigable drill selector via `Table1.Option` (in-game Table Options)
- [x] README, ATTRIBUTION, CHANGELOG, docs, test procedure T1
- [x] Headless load check on the gaming PC: `-Audit` confirms the table loads
      with no script error (see `docs/physics.md` for what it flagged)
- [ ] **Run T1a (desktop smoke test)** on any Windows VPX host, VM included
- [ ] **Run T1b (VR validation)** on the gaming PC with a Quest 3

## Milestone 2: physics and lower playfield

- [ ] Apply VPW flipper geometry and physics values to `Flipper.*.json`
- [ ] Apply VPW table-level physics to `gamedata.json` (friction, scatter, tilt angle)
- [ ] Add `scripts/40-physics-nfozzy.vbs`: `FlipperPolarity` class, correction
      triggers, polarity / velocity / Ycoef tables
- [ ] Add `scripts/45-physics-damping.vbs`: rubber dampeners, TargetBouncer
- [ ] Consider the Fleep mechanical sound set
- [ ] Credit every ported block in ATTRIBUTION.md as it lands
- [ ] Port the rolling-sound code off the 10 ms `RollingTimer` onto a
      frame-synchronised callback. VPX's audit warns it breaks frame pacing,
      which matters for a timing trainer and collides with 90 Hz VR.
- [ ] Prune the unused stock asset library from `table/src/gameitems/`
      (bumper caps, pegs, rulers, alternate flipper models: ~26 MB of `.obj`,
      measured at 220 MB of GPU memory by VPX's audit)
- [ ] Write and run test procedure T2

## Milestone 3: repeatable ball feeder

- [ ] Decide the delivery mechanism (invisible kicker vs direct velocity set
      vs guided chute). Repeatability outranks visual realism.
- [ ] `scripts/60-feeder.vbs`: create, position, launch, select side, bound
      randomisation, repeat, snapshot pre-contact state
- [ ] Feed profile table in `10-config.vbs`
- [ ] Visual markers for launch position and intended contact point (debug only)
- [ ] Write and run test procedure T3

## Milestone 4: drop catch MVP

- [ ] `scripts/70-scoring.vbs`, `scripts/80-drills.vbs`, `scripts/90-ui.vbs`
- [ ] Left and right drop catch drills, 10-attempt sets, reset/repeat
- [ ] VR-safe training display
- [ ] In-world flipper/MagnaSave menu for in-flow control, so changing drills
      mid-session does not require opening the modal in-game UI
- [ ] Wire keys 1, 2, 3 and R to real behaviour

## Later milestones

5 variable drop catch, 6 live catch, 7 dead bounce, 8 post pass and cradle
separation, 9 accuracy, 10 mixed recognition. See
[`docs/drill-design.md`](docs/drill-design.md).

## Open questions

- [ ] Obtain the VPW Example / Basic table as a cleaner physics source. See
      [`reference/README.md`](reference/README.md). Not blocking.
- [ ] Decide whether real CSV file output from VPX script is workable on
      Windows, or whether the log stays an in-memory buffer with manual export.
- [ ] VR-safe text rendering approach for the training display: flasher,
      textured primitive, or backbox surface.
