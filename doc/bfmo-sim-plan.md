# Prompt: hoon-native io-driver simulation for BFMO testing

Goal: retire the aqua/lago apps. Port vere's io-driver *logic and state* to
hoon, drive them with a combined strandio+state monad, and run whole-fleet
tests as pure computations — libuv events in, libuv effects out — checkable
inside a ship, or from a bare C test binary against a modified ivory pill.

---

# STATUS (updated after the P1/P2 work; read this first)

Branch `bfmo/develop-port` in **`~/PLAN/urbit-bfmo`** (renamed from
`vere-bfmo`; it is a git worktree of `~/PLAN/urbit`). Pushed to
`git@github.com:sarpen-laplux/urbit.git`. Companion C worktree is
**`~/PLAN/vere-bfmo`** (branch `bfmo/harness`, off urbit/vere
`origin/develop`) — see "Runtime" below. Do not touch branch `sl/cba`;
it is the user's, unrelated to this work.

## Done

- **`sur/sim-uv.hoon`** — the uv boundary vocabulary. `$uv-event`
  (%talk/%timer-fire/%news/%exit), `$uv-effect` (%timer-start/-stop,
  %close, %bail, %slog, %write, %save, %browse, %pier-exit), `$hid`,
  `$bail-mote` (%dire vs %soft, mirroring `_behn_bail_dire`).
- **`lib/sim-io.hoon`** — the `sio` monad builder, lia-shaped:
  `(sio state-mold)` then `(thread-form:sm result-mold)`; state threads
  through form application, `%done`/`%fail` yields only. Arms: `pure`,
  `fail`, `bind`, **`pin`** (the rune-free `;^`: continuation sample is
  `[result state]`), `get`, `put`, `jab`, `lift-eng`. Cross-mold shapes
  are top-level builders `sio-yild` / `sio-form` — they must NOT be
  door arms, a spec position rejects `limb:(call)`.
- **`lib/sim-behn.hoon`** — `behn.c` ported field-for-field, every arm
  citing its C origin. Covers the doze lifecycle, `_behn_time_cb`'s
  ten-minute backstop, the born/wake retry ladders, `%exit` close.
- **`lib/sim-term.hoon`** — `term.c`'s semantic layer: belts in, blits
  applied to a cursor/line/transcript screen model, %write/%save/
  %browse/%pier-exit out. The raw escape/utf8 parser is deliberately
  unmodeled (input enters at `$belt`, where vere hands it to arvo).
- **Tests, all green in-ship** (`-test %/tests/sim`): behn 9, term 7,
  including one exercising the `sio` monad end to end.
- **A real BFMO bug found and fixed in passing**: `app/lens.hoon`
  unconditionally `%leave`d dojo on the first sole fact. Under BF,
  dojo's prompt fact (emitted in `on-watch`) arrives before the command
  poke's output, so the result was orphaned and every later HTTP dojo
  request 500'd on the stuck `job.state`. Fixed order-tolerantly
  (leave only once `take-sole-effect` served a response) — the model
  fix for the poke-ack/fan-out class in `doc/bfmo-audit.md`.

## In progress — the one thing to pick up first

**`lib/sim-fleet.hoon` has an unresolved nest-fail.** The library builds;
the driver test does not. Test is quarantined at `tests/wip/fleet.hoon`
(move it back to `tests/sim/` when fixed) so the suite stays green.

The trace reads `need = <gate taking world>`, `have = [[%done ~] world]`
— i.e. an action's *product* is reaching a position that wants the
action itself. Actions are already cast `^- form:m` / `^- form:ml`
(strandio idiom); `run-driver-res` arity is already fixed. Next step is
a dojo bisect (~60s per round, see Workflow below):

```
=sf -build-file %/lib/sim-fleet/hoon
!>((spawn:sf ~zod !>(0)))              :: gate, or already a product?
!>(((spawn:sf ~zod !>(0)) *world:sf))
```

Ruled out already: the two adjacent top-level `|%` cores parse fine
(inserting `=>` between them only breaks the terminator). Remaining
suspects: (a) the `^-` cast binding to the wrong gate in `spawn`;
(b) `form:m` closing over a subject the call site does not share,
since `m`/`ml` are computed in the second core.

What `sim-fleet` already contains and is worth keeping: `$world`
(fleet map, clock, effect log), `$ship-sim` (kernel vase + per-driver
states + the uv-side `uvh` handle table), the kernel `+poke` slam loop
(aqua's pattern, so a mock kernel works in unit tests before ivory-dev
exists), arvo-effect routing by wire head, `+warp` firing due timers in
date order across the fleet, and `+logs` for per-ship assertions.

## Not started

- ames/mesa engine (the big P2 item), two-ship routing, `-ph-hi` port.
- P3 `;^` rune (spec below unchanged; `pin` is the working fallback —
  write everything with `pin` first, the rune is pure sugar over it).
- P4 ivory-dev pill + `sim_tests.c` + zig test step.
- P5 corpus port.

## Runtime / harness (this did not exist when the plan was written)

- **`~/PLAN/vere-bfmo`**, branch `bfmo/harness` off urbit/vere develop,
  three commits: two genuine upstream bug fixes (boot-time tank-trace
  rendering; the malformed speculative `wynn` in `_mars_wyrd_card`
  that caused `arvo: bad wisp`, plus serf-side goof printing) and one
  `XX BFMO` commit declaring the decremented kelvin stack
  (zuse 407 / lull 319 / arvo 233). **Not built yet** — needs
  `git lfs pull` (two generated `.c` files are LFS pointers) then
  `zig build -Doptimize=ReleaseFast`, ~10 min.
- The currently-working binary is `~/PLAN/vere/zig-out/aarch64-macos-none/urbit`
  (same patches, older base). The harness scripts point at it.
- **`~/PLAN/bfmo-piers/`**: `boot.sh` (fresh fake-ship boot + smoke),
  `ota.sh` (live upgrade driver), **`ptydrive.py`** (drives dojo over a
  pty; `SLEEP:n` pseudo-command interleaves background curls).
  `port-pier` is a booted BFMO ship; `base-pier` a develop baseline.

## Workflow that makes this fast

Do NOT reboot to test hoon changes. Userspace edits go:

```
rsync -L pkg/base-dev/lib/<file>.hoon ~/PLAN/bfmo-piers/port-pier/base/lib/
python3 ~/PLAN/bfmo-piers/ptydrive.py ~/PLAN/bfmo-piers/port-pier \
  '|commit %base' 'SLEEP:25' '-test %/tests/sim' 'SLEEP:45'
grep -aE 'FAILED|OK  |nest|-find|syntax' ~/PLAN/bfmo-piers/pty-session.log | tail
```

~60s per round vs ~4 min for a reboot. Kill stale ships first
(`pkill -f 'urbit.*port-pier'`); a stale `.vere.lock` blocks restart.
Note `tests/` is copied into `pkg/arvo/tests/` for the desk (untracked);
keep `tests/sim/*` and `pkg/arvo/tests/sim/*` in sync, and new libs need
a symlink in `pkg/arvo/lib/` (`ln -sf ../../base-dev/lib/X.hoon X.hoon`).

## Hoon error classes already hit (save yourself the round trip)

- `limb:(wet-call)` in a **spec** position → `syntax error`. Hoist to a
  top-level mold builder (`++ sio-form |* a=mold $-(...)`).
- `/+` before `/-` → `syntax error` at the ford line. `/-` first.
- `res` is a **type** in the engines, not a face: write `fx.r`, not
  `fx.res.r`.
- Date arithmetic loses its aura: `` `@dr`(sub a b) `` or you get
  `-need.@dr -have.@ud`.
- `[%txt "hi" ~]` is not a `$belt`: use `[%txt (tuba "hi")]`.
- Passing `[fx ova]:r` to a `|= [fx=... ova=...]` gate supplies one
  argument, not two.

---

## Study targets (read these first, in this order)

1. `pkg/base-dev/sur/wasm/lia.hoon` + `pkg/base-dev/lib/wasm/lia.hoon` —
   the Lia script monad. The load-bearing shapes:
   - `script-raw-form yil acc = $-((lia-state acc) [(script-yield yil) (lia-state acc)])`
   - `script-yield a = $%([%0 p=a] [%1 name args] [%2 ~])` — done / call-out
     (suspend into the host) / fail
   - `++script |* [m-yil m-acc]` — the doubly-parameterized builder; `try`
     is bind, threading state with `=^`.
   This is the exact "monad-builder over a state mold, thread-form over a
   result mold" pattern we want, with %1 as the strandio-style suspension.
2. `~/PLAN/vere/pkg/noun/jets/e/urwasm.c` — how the host reduces such a
   monad in C (`_reduce_monad`, `lia_state`, `lia_suspend_tag`, versioned
   jet motes like `uw__lia + c3__run + version`). We are NOT jetting yet;
   read it to keep the hoon representation jet-friendly (flat state trel,
   tagged yields, no closures in state).
3. `~/PLAN/vere/pkg/vere/io/*.c` — the driver inventory to port:
   `behn.c` (timer), `term.c` (tty), `http.c` (server), `cttp.c` (client/
   iris), `ames.c` + `mesa.c` (UDP + mesa framing), `unix.c` (clay sync),
   `conn.c`, `lick.c`, `fore.c`/`hind.c` (boot phases), `lss.c`.
   For each: the `u3_XXXX` state struct, its libuv callbacks (events IN),
   its libuv calls (effects OUT), and its arvo-facing ovum/effect vocab.
4. `~/PLAN/vere-hamt/pkg/vere/boot_tests.c` + its `build.zig` test-step
   registration — the C instrumentation pattern: embed an ivory pill
   (`u3_Ivory_pill`), `u3m_boot_lite` + `u3v_boot_lite`, then evaluate.
   ~70 lines total; our `sim_tests.c` should look like it.
5. `pkg/arvo/gen/pill/ivory.hoon` and vere's `u3v_wish` path — what the
   ivory pill contains and how wishes evaluate against it.
6. `pkg/arvo/ted/ph/*.hoon` + `pkg/base-dev/lib/ph/*.hoon` (and the lago
   equivalents in ~/PLAN/urbit-lago) — the test corpus to port, and the
   vocabulary of fleet operations it needs (dojo, breach, hi, sunk, OTA).

## Architecture

Three layers, bottom-up:

### L1 — driver engines (non-effectful doors, one per vere io driver)

For each driver, define in `pkg/base-dev/`:

- `sur/sim/uv.hoon`: the shared libuv vocabulary.
  - `$uv-event`: tagged per driver — e.g. `[%timer-fire hid=@ud]`,
    `[%udp-recv hid=@ud lane=[ip=@if port=@ud] data=octs]`,
    `[%tcp-conn hid=@ud ...]`, `[%tty-belt belt]`, `[%fs-...]`.
  - `$uv-effect`: e.g. `[%timer-start hid=@ud wen=@da]`,
    `[%timer-stop hid=@ud]`, `[%udp-send hid lane data]`,
    `[%tcp-write hid octs]`, `[%close hid]`, `[%open-udp port]` ...
  - `$hid`: opaque handle id (@ud), allocated by the engine.
- `lib/sim/<driver>.hoon`: a door
  `|_ [state] +call: [uv-event] -> [(list effect) state]`
  and `+take: [arvo-effect] -> [(list uv-effect) (list ovum) state]`
  mirroring the C driver as directly as possible: port the `u3_XXXX`
  struct fields to a `$state` mold field-for-field (document each field's
  C origin in a comment), and port each libuv callback body and each
  arvo-effect handler body.

The engine mediates both directions: libuv events become arvo ova (the
existing `$unix-event`/card vocabulary — do not invent a new arvo-facing
vocab); arvo effects (%doze %send %blit %response ...) become uv-effects.

Handle discipline: engines allocate hids; the engine's state carries a
`live=(map hid handle-meta)` table. Abstract the C close/free dance:
one-shot handles (a timer that fired, a completed http response) are
retired implicitly by the engine — emit `[%close hid]` yourself and drop
the table entry, so tests never see boilerplate closes. Long-lived handles
(listening sockets, the tty) close only on explicit `%exit`/driver
teardown. Assertions about leaks become possible: a test can check
`live` is empty (or exactly the persistent set) at the end.

### L2 — the monads (this is where the user's design sketch lands)

Two builders, both in `pkg/base-dev/lib/sim/monad.hoon`:

**(a) `sio` — the driver/state monad** (lia-shaped, no fleet knowledge):

```hoon
++  sio                                  ::  monad builder
  |*  sat=mold                           ::  (sio state-mold)
  |%
  ++  output  |*  a=mold  [yield=(sio-yield a) =sat]
  ++  form    |*  a=mold  $-(sat (output a))     ::  thread-form
  ++  pure    |*  ...                            ::  %done
  ++  bind    |*  ...                            ::  =^-threads state
  --
```

with `sio-yield a = $%([%done p=a] [%emit fx=(list uv-effect) self]
[%fail err=tang])`. Answering the design question posed: make it
lia-style — **state is threaded through form application, not stored in
the yield**. `%done` yields the value; the state comes back alongside the
yield in `output` (so the caller gets both, as required). `%cont`/`%emit`
carries only the continuation; its state arrives when the driver of the
monad applies it. This keeps `;^`'s desugar clean (below), keeps yields
small/jet-friendly, and matches both lia and strand precedent. Reject the
state-in-yield variant: it duplicates state (yield and application) and
makes bind's `=^` awkward.

**(b) `fleet` — the test monad** (strandio-analog the ph/lago tests port
to). Its state mold:

```hoon
+$  ship-sim
  $:  kor=vase                           ::  kernel core (+le or full arvo)
      eve=@ud                            ::  event count
      now=@da
      drivers=[behn=behn-state term=term-state ames=ames-state ...]
  ==
+$  world  [fleet=(map ship ship-sim) wen=@da]
```

`=/ sm (sio world)`, `=/ m (form:sm result-mold)`. Actions:

- `(inject who=ship ev=uv-event)` — route to that ship's driver engine,
  produce ova, poke the ship's kernel, take arvo effects back through the
  engines, collect uv-effects. Returns `(list [ship uv-effect])`.
- `(expect-fx who filter)` / `(expect-no-fx ...)` — assertions.
- `(warp dt=@dr)` — advance now; fire due behn timers (the behn engine
  knows the next-wake set — time travel replaces aqua's timer loop).
- `(dojo who tape)` — sugar: inject tty belts, gather blits, parse.
- ship lifecycle: `(boot who pill)`, `(breach who)`, network delivery
  between ships: `%udp-send` effects from A auto-route as `%udp-recv`
  events to B when both are in the fleet (with an optional drop/delay
  hook for failure-mode tests — this replaces lago's shims).

Whether (a) and (b) are literally two instantiations of one builder or
`fleet` is `(sio world)` plus a library of actions: prefer the latter —
ONE monad builder, two state molds. Only split into a genuinely distinct
second monad if the driver-internal logic turns out to want suspensions
that the world-level monad must not see. Start unified; report back if
the seam forces a split.

### L3 — harnesses

**In-ship**: the whole thing is pure hoon over base-dev; `-test %/tests`
runs it (tests in `tests/sim/*.hoon`). This works today, no vere changes.

**Bare-metal (the ivory route)**: a pill variant + C test file:

1. `pkg/arvo/gen/pill/ivory-dev.hoon`: ivory plus, compiled into the
   subject: `lib/pill` and the sys sources (so `+wish` can BUILD pills:
   `(wish "(solid-like-expression ...)")` returns a pill noun), and the
   sim libraries + a `+run-sim-test` gate: `$-(test-name (unit tang))`.
2. `~/PLAN/vere/pkg/vere/sim_tests.c`, cloned from vere-hamt's
   `boot_tests.c`: embed/load ivory-dev, `u3m_boot_lite`+`u3v_boot_lite`,
   then `u3v_wish("(run-sim-test %ames-hi)")` per test; nonzero exit on
   failure tang (render it with the trace printer already added to this
   fork). Register a zig test step like hamt's `boot-test`.
3. The pill-building wish lets the C harness synthesize the *kernel
   under test* for `ship-sim.kor` without a running ship: wish once to
   build a solid-ish kernel vase from the mounted sources, then feed it
   to the fleet monad. This closes the loop: BFMO kernel + hoon drivers
   + C runner, no pier, no aqua.

Note the ivory pill's lifecycle differs from brass (no vanes, no ship);
"allows one to build pills via +wish" means the ivory-dev subject must
include the pill lib AND a file-tree of sys sources (bake the sources in
as a `(map path cord)` at pill-build time — same trick aqua's `-A`
substitute uses, but frozen into the pill).

## The `;^` (mickét, %mckt) rune

A combined `;<` + `=^` with the state leg hidden. Surface syntax:

```hoon
;^  skin  bind:m  foo
cont-body
```

Desugars to (per the agreed sketch):

```hoon
%+  bind:m
  foo(<state-axis> __sim-state)
|=  [skin state=_<state-mold>]
=*  __sim-state  +<+
cont-body
```

Design points to settle during implementation, with recommendations:

- **Sentinel face**: use a reserved face (`sim` or `__state`) bound via
  `=*` to `+<+` in the continuation, and expected to be in scope at the
  `;^` site (established by the monad's entry macro, e.g. a `%-`-style
  `run:sm` wrapper that binds it once). The `foo(... __sim-state)` leg
  re-points the action's state slot at the current sentinel, which is
  what makes sequential `;^`s thread state invisibly. Document that the
  sentinel is an alias (=*), not a copy — mutations via classic `=^`
  still compose underneath.
- **Where**: `hoon.hoon` — add `[%mckt p=skin q=hoon r=hoon s=hoon]` to
  `$hoon`, parse in the mic-rune battery in `+vast` (four-argument rune,
  tall and wide forms; glyph `;^`), expand in `+open`/`+ap` as pure
  sugar. No nock or type-system changes. This edits hoon.hoon on the
  fork: note it in the kelvin ledger (hoon %136 is being modified;
  either bump to %135 on this branch or mark the rune experimental in
  the commit — decide with the same reasoning as the zuse/lull bumps).
- **Fallback**: also ship a `;^`-free spelling (a `|*` helper, e.g.
  `(pin:sm foo |=([skin _st] body))`) so the sim libraries and tests can
  be written before the rune lands, and so out-of-tree code isn't forced
  onto a forked hoon. The rune then becomes sugar over `pin`.
- If the `=^`-flavored variant is wanted too (action returns
  `[result state]` explicitly, e.g. porting existing engine arms), add
  it as the same rune with the action's type driving which expansion —
  or don't: keep `;^` single-meaning and provide `lift-eng:sm` to wrap
  an engine arm `$-([ev state] [fx state])` into the monad. Prefer the
  latter; runes that dispatch on inferred type are a foot-gun.

## Porting the test corpus

Inventory first: list every `ted/ph/*` and lago test with the fleet
operations it uses. Expected buckets: hi/plea flows, breach+rekey, OTA
(child-sync, kelvin), timers (behn), scry (%keen/mesa), flub/halt, boot.
Port order: `-ph-hi` (two ships, one message — the hello-world of the
harness) → breach-hi → timers → flub/mesa-halt → child-sync/OTA (needs
the pill-building wish). Each port should read *better* than the aqua
original — if it doesn't, the fleet-action vocabulary is wrong; fix the
vocabulary, not the test.

Acceptance for the whole effort:

1. `-ph-hi`-equivalent runs green three ways: in-ship `-test`, and via
   `sim_tests.c` against ivory-dev, on the BFMO branch.
2. At least one test that BFMO semantics makes interesting (poke-ack
   sibling ordering, or the boot blocked-queue case from
   `doc/bfmo-audit.md`) is expressed as uv-events/effects assertions.
3. A leak check: fleet teardown asserts no unexpected live handles.
4. No aqua/lago app dependency anywhere in the new tests.

## Phasing

(Status per phase is in the STATUS section at the top of this file;
P1 is done, P2 is partly done. File names landed slightly flatter than
sketched below: `sur/sim-uv.hoon`, `lib/sim-io.hoon`, `lib/sim-behn.hoon`,
`lib/sim-term.hoon`, `lib/sim-fleet.hoon`.)

- P1: study + write `sur/sim/uv.hoon` vocabulary + behn engine (smallest
  driver) + the `sio` builder + `pin` helper. Unit-test behn engine
  round-trip in-ship.
- P2: term + ames/mesa engines; fleet monad + two-ship routing; port
  `-ph-hi`. (mesa's framing logic in `mesa.c` is large — port the state
  machine, stub crypto where the C defers to urcrypt with the hoon
  equivalents already in zuse.)
- P3: `;^` rune in hoon.hoon + convert the sim libs/tests to it.
- P4: ivory-dev pill gen + `sim_tests.c` + zig step; pill-building wish.
- P5: port the remaining ph/lago corpus; delete nothing yet — run both
  suites side by side until the port has caught every regression the old
  suite catches; keep the BFMO-specific tests from bfmo-audit.md's
  testing-debt list in this framework.

Open questions — now decided in code, recorded here:

- **Granularity**: vere's io-driver callbacks, not raw libuv. Settled;
  `$uv-event`/`$uv-effect` in `sur/sim-uv.hoon` are at the callback
  level and each cites its C origin.
- **`kor`**: full arvo formal interface. `+poke-kernel` slams the
  `+poke` arm, so anything with arvo's shape works — a mock core for
  unit tests today, real arvo from the ivory-dev wish later. This is
  what makes the harness exercise BFMO's actual move loop.
- **Clock**: single global clock in `world`, advanced by `+warp`, which
  fires due timers across the whole fleet in date order. Settled.

Still open: whether `+warp` should also drain any non-timer pending
work before returning; whether the fleet needs per-ship clock skew for
network-partition tests (not needed for `-ph-hi`).
