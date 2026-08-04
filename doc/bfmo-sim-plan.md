# Prompt: hoon-native io-driver simulation for BFMO testing

Goal: retire the aqua/lago apps. Port vere's io-driver *logic and state* to
hoon, drive them with a combined strandio+state monad, and run whole-fleet
tests as pure computations — libuv events in, libuv effects out — checkable
inside a ship, or from a bare C test binary against a modified ivory pill.

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

Open questions to resolve early (flag, don't guess silently): exact
`$uv-event`/`$uv-effect` granularity (1:1 with libuv, or with vere's
io-driver callbacks — recommend the latter: vere's callbacks are already
the semantic layer, libuv-raw adds noise); whether `kor` holds full arvo
or per-vane cores (start with full arvo formal interface: poke/peek/wish
— it exercises BFMO's actual loop, which is the point); how `now`
interacts with per-ship clocks under `warp` (single global clock first).
