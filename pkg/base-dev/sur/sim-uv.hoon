::  sim-uv: the vere-host boundary vocabulary for io-driver simulation
::
::    $uv-event: the host (libuv callbacks + vere's auto/peer plumbing)
::    speaking to a driver engine.  $uv-effect: a driver engine speaking
::    to the host.  each arm cites the C callsite it mirrors; the
::    vocabulary is at the granularity of vere's io-driver callbacks,
::    not raw libuv.
::
|%
::  $hid: opaque live-handle id
::
::    allocated by the harness (one namespace per ship); an engine is
::    given its long-lived hids at +init and requests fresh ones for
::    per-request handles via [%open ...] effects.
::
+$  hid  @ud
::  $sim-card: arvo-bound event payload, as vere plans it
::
+$  sim-card  (cask)
+$  sim-ovum  [=wire card=sim-card]
::  $bail-mote: how a planned event failed
::
::    %dire is a fatal mote (_behn_bail_dire: %meme, %intr are NOT
::    dire; everything else is).  %soft covers meme/intr.
::
+$  bail-mote  ?(%dire %soft)
::  $uv-event
::
+$  uv-event
  $%  ::  driver start; vere calls io.talk_f once at pier start
      ::
      [%talk ~]
      ::  uv_timer_cb fired
      ::
      [%timer-fire =hid]
      ::  a planned ovum was computed (u3_ovum_news %done) or
      ::  failed (peer bail callback)
      ::
      [%news =wire res=$%([%done ~] [%bail =bail-mote])]
      ::  driver teardown; vere calls io.exit_f
      ::
      [%exit ~]
  ==
::  $uv-effect
::
+$  uv-effect
  $%  ::  uv_timer_start, milliseconds-from-now expressed as @dr
      ::
      [%timer-start =hid gap=@dr]
      ::  uv_timer_stop
      ::
      [%timer-stop =hid]
      ::  uv_close; the handle is dead, hid may be reused
      ::
      [%close =hid]
      ::  u3_pier_bail
      ::
      [%bail ~]
      ::  u3l_log
      ::
      [%slog =tape]
  ==
--
