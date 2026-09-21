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

- [x] Survey every local VPW table and pick a reference (LOTR Stern 2003)
- [x] Apply VPW flipper geometry and physics values to `Flipper.*.json`
- [x] Apply VPW table-level physics to `gamedata.json` (friction, scatter, tilt angle)
- [x] `scripts/40-physics-nfozzy.vbs`: `FlipperPolarity`, flipper tricks, EOS,
      live catch, cradle collision, correction triggers
- [x] `scripts/45-physics-damping.vbs`: rubber dampeners, CoR tracker, TargetBouncer
- [x] `scripts/12-physics-config.vbs`: Modern Stern profile + Global Physics assertion
- [x] Port the rolling sound off the 10 ms `RollingTimer` onto a per-frame
      timer. VPX's audit warning is now gone.
- [x] Static validation that every referenced table object exists (`tools/check.py`)
- [x] Credit every ported block in ATTRIBUTION.md
- [x] Automated validation harness (`scripts/65-validation.vbs`) with timing
      and feed-speed sweeps
- [x] Drop catch, cradle, dead bounce and speed sweeps run. Timing
      discrimination 0.6945: good timing kills 71% of the ball's energy, bad
      timing almost none. Physics responds correctly to timing.
- [ ] **Build out the lower playfield geometry.** The sweeps show the ball
      never settles against a raised flipper at any feed speed
      (distFromBase >= 157 vpu always), because there are no inlane guides to
      route it into the cradle corner. This blocks cradle, post pass and
      cradle separation. It is a geometry problem, NOT a physics constant to
      retune.
- [ ] Judge whether the return speed feels realistic (needs a human)
- [ ] Live catch sweep (`valid-live`) once geometry supports a catch
- [ ] Populate the `dSleeves` collection once sleeve rubbers exist
- [ ] Consider the Fleep mechanical sound set
- [ ] Prune the unused stock asset library from `table/src/gameitems/`
      (bumper caps, pegs, rulers, alternate flipper models: ~26 MB of `.obj`,
      measured at 220 MB of GPU memory by VPX's audit)
- [ ] Write and run test procedure T2

## Milestone 3: repeatable ball feeder

- [x] Delivery mechanism chosen: direct position + velocity, via an invisible
      zero-scatter spawn kicker. Reasoning in `scripts/60-feeder.vbs`.
- [x] `scripts/60-feeder.vbs`: create, position, launch, select side, bound
      randomisation, repeat, snapshot pre- and post-contact state
- [x] `FeedProfile` class with per-side profiles and difficulty-scaled jitter
- [x] Calibration harness: 20 fixed feeds, reports mean / sd / spread
- [x] Engineering keys F, G, C
- [x] **T3 PASSED** (automated, 2026-09-21): 20/20 feeds reached the flipper,
      pre-contact speed varies 0.56%, contact lands within 10 vpu of target
- [x] Headless self-test harness (`-CaptureAttract` + `-c1 probe|feed|calib`)
- [ ] Judge whether 9.16 is a realistic return speed (needs a human)
- [ ] Visual markers for launch position and intended contact point (debug only)

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
