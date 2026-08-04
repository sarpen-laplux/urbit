# BFMO port: audit record and open items

Move-emission catalogue of all ten vanes + arvo machinery under the BFMO
hazard taxonomy (sibling-order, cascade-dependency, pinned-scry staleness,
fan-out, reentrancy, accumulator discipline). ~385 sites enumerated, 100%
examined. Fixed items are in the git history; this file records what was
*deliberately not* fixed and the open questions verification must answer.

## Semantic changes userspace must know about (release-note material)

- **Poke-ack ordering.** "Poke, then %watch from the %poke-ack handler"
  no longer sees facts the pokee emitted in the same arm: the ack and the
  fact fan-out are siblings, fan-out first. Subscribe before poking, or
  tolerate missing the first fact.
- **Init round-trips.** A newly installed agent's queued deals are
  delivered as siblings of its on-init, not after on-init's cascade.
  Agents must not assume a %warp/%wait/%public-keys round-trip completes
  before their first poke/watch arrives. (gall could defer the blocked-
  queue flush behind a continuation instead; design decision open.)
- **Served generators** (%eyre %serve): sample head is now
  `[now=@da tick=@ud eny=@uvJ bek=beak]`; scries must carry the tick
  (build paths from `our` + `(en-cose da+now ud+tick)`, not from `bek`).
  Old-shape generators 500.
- **byk.bowl carries a tickless beak** (installed-at marker). Consumers
  must re-stamp: `byk.bowl(r [da+now.bowl ud+tick.bowl])`. Scrying via
  bare byk.bowl silently returns ~.

## Known-deferred defects (pre-existing or design-needed; not fixed)

- **eyre kicks channels on blocked namespace reads** (+app-to-desk %gd,
  +channel-event-to-json %cf): a `~` (blocked/rejected) read is treated
  like "conversion impossible" and permanently kills the subscription.
  BFMO widens the window (pinned rooks can't see sibling clay commits).
  Fix direction: distinguish `~` from `[~ ~]` before kicking.
- **dill %logo truncation**: on a hood watch-ack failure the exit effect
  is emitted before the diagnostic %logs cascade produces blits; the
  terminal loses the explanation. Fix direction: drip the %logo.
- **gall +ap-handle-kicks defeats +ap-kill-up-slip's on-leave** (bitt
  entry deleted before the %leave slip arrives → on-leave never called).
  Pre-existing, orthogonal to BFMO.
- **iris drops a second %request on a live duct silently** (~&-and-drop);
  a caller whose %cancel-request is a cascade descendant now loses the
  race and hangs. Fix direction: give an error response instead.
- **ames on-migrate `prod-move` is dead code** whose comment encodes a
  DF guarantee ("after the %mokes have been processed") that BF does not
  provide. Do not re-enable it as written.
- **gall +ap-ingest ack-first weld** is only correct because ack-moves
  is always a singleton (it is welded unflopped). Fragile.
- **eyre by-channel `moves` accumulator** is documented "reversed" but
  spliced unflopped on three paths; currently unobservable. Pick one.

## Open questions for verification (V-track) to answer

1. Remote scry cases: do %fine/mesa request paths ever carry `[%da now]`?
   If so they now block forever (%no-tick). Decide `~` vs `[~ ~]` for
   peer-supplied bare-now cases. (ames peek-publ/chum/shut/whey)
2. flow-roof's shadow guard matches spur only, bypassing the tick check
   arvo would enforce; should it also match ship/desk/case?
3. ma-get-page mixes live in-core reads with pinned-rof namespace
   re-entry (peek-chum/shut/publ). No live failure constructible today;
   any future worklist with two %moke/%mage for the same flow diverges
   silently. Wants an invariant or a comment in ames.
4. gall %x boon path emits [%kick, %a %cork] as siblings; the re-watch
   travels on a fresh nonce wire so the cork should target only the old
   bone — confirm ames-side that corking bone n cannot clobber a flow
   opened later in the same event.
5. Does any agent hold its own %j %public-keys subscription and
   re-subscribe to a breached ship in its immediate on-agent? (Would
   have needed the full DF sorter; we restored only the gall-vane-first
   partition.)
6. clay %vega wake-all iterates desks tail-first (reverse order) unlike
   %ogre/%cred; pre-existing inconsistency, looks unintentional.
7. Tick-0 is shared by external peeks and (pre-fix) restored legacy
   plans; if any userspace consumer uses [now tick] as a snapshot
   identity, distinct tick-0 snapshots conflate.

## Testing debt (S6)

- tests/sys/arvo/bf.hoon: instantiate +le; assert sibling-before-children
  order, per-worklist tick monotonicity, %no-tick/%bad-tick rejection,
  pinned-rook staleness, and the +jump properties (re-pin, %vega-first).
- Re-derive tests/sys/grq.hoon t16-t20 interleaving under BF (its
  hand-driven order is DF-shaped) or annotate as fixture order.
- ph test for the fan-out archetype (subscriber B's fact handler scries
  subscriber A's state) to pin the documented semantics.
- OTA test exercising +sys-update's [/what, %zeal, %pork] path and the
  a234 debt conversion.

## V-track live status (session handoff)

Port BOOTS; console dojo fully works (pty driver). Open bug: lens/HTTP.
Fresh pier: request 1 sets job.state + watches dojo, but the response
chain never completes (curl gets nothing); request 2 then crashes on
lens.hoon:84 `?> ?=(~ job.state)` (spot-only tang, eyre 500 + %leave).
Suspect: dojo-side sole flow stalls under BF (check lens on-agent
watch-ack -> %sole-action poke to dojo, and dojo's ticked scries).
Tools: ~/PLAN/bfmo-piers/{boot.sh,ota.sh,ptydrive.py}; patched fork
runtime in ~/PLAN/vere (kelvins 407/319/233, wynn fix, trace renderer,
serf goof printing). |verb move-trace confirmed BF delivery working.
