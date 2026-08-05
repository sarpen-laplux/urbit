::  sim-fleet: multi-ship world state and actions over sim-io
::
::    XX WIP: nest-fail when driven from tests/wip/fleet.hoon.
::    The trace reads need=<gate taking world> have=[[%done ~] world]
::    -- an action's *product* supplied where a form (gate) is
::    wanted.  Actions are now cast ^- form:m / ^- form:ml (strandio
::    idiom), so the next step is a dojo bisect:
::      =sf -build-file %/lib/sim-fleet/hoon
::      !>((spawn:sf ~zod !>(0)))        :: is this a gate?
::      !>(((spawn:sf ~zod !>(0)) *world:sf))
::    Suspect the two adjacent top-level |% cores (types core is not
::    in the actions core's subject via =>, yet `world` resolves --
::    verify what subject `form:m` closes over).
::
::
::    each ship is a kernel vase (anything with a +poke arm shaped
::    like arvo's formal interface: [now=@da ovum] -> [(list ovum) _core];
::    real arvo via the ivory-dev wish, or a mock core in unit tests)
::    plus one instance of each ported io driver and the uv-side
::    live-handle table (the "libuv" half: armed timers etc).
::
::    the event loop per injected uv-event:
::      driver engine -> [uv-effects, ova]
::      each ovum -> kernel +poke -> arvo effects
::      each arvo effect -> the owning driver's +take -> uv-effects
::    uv-effects append to the world's log (tests assert on it) and
::    update the handle table.  +warp advances the clock and fires
::    due timers.
::
/-  *sim-uv
/+  sim-io, sim-behn, sim-term
|%
+$  handle  $%([%timer wen=(unit @da)])
+$  ship-sim
  $:  kor=vase
      nex=hid                            ::  next handle id
      uvh=(map hid handle)               ::  live handles (the uv side)
      behn=behn-sim:sim-behn
      term=term-sim:sim-term
  ==
+$  world
  $:  fleet=(map ship ship-sim)
      wen=@da
      log=(list [who=ship fx=uv-effect])
  ==
::  driver-tagged event for +inject
::
+$  drive  $%([%behn ev=uv-event] [%term ev=uv-event] [%belt bet=*])
--
|%
++  sm  (sio:sim-io world)
++  m   (thread-form:sm ,~)
++  ml  (thread-form:sm (list uv-effect))
::  +poke-kernel: slam the kernel's formal +poke (aqua's pattern)
::
++  poke-kernel
  |=  [kor=vase now=@da ovo=sim-ovum]
  ^-  [(list sim-ovum) vase]
  =/  gat  (slap kor limb/%poke)
  =/  res  (slam gat !>([now ovo]))
  [;;((list sim-ovum) -:!<(^ res)) (slot 3 res)]
::  +apply-fx: log effects and maintain the uv handle table
::
++  apply-fx
  |=  [who=ship fx=(list uv-effect) sim=ship-sim wol=world]
  ^-  [ship-sim world]
  =.  log.wol  (weld log.wol (turn fx (lead who)))
  |-
  ?~  fx  [sim wol]
  =?  uvh.sim  ?=(%timer-start -.i.fx)
    (~(put by uvh.sim) hid.i.fx [%timer `(add wen.wol gap.i.fx)])
  =?  uvh.sim  ?=(%timer-stop -.i.fx)
    (~(put by uvh.sim) hid.i.fx [%timer ~])
  =?  uvh.sim  ?=(%close -.i.fx)
    (~(del by uvh.sim) hid.i.fx)
  $(fx t.fx)
::  +run-ovum: kernel poke, then route arvo effects to drivers
::
::    arvo effects come back as [wire card]; the wire's head names
::    the driver (vere's io drivers pattern-match the same way).
::
++  run-ovum
  |=  [who=ship ovo=sim-ovum sim=ship-sim wol=world]
  ^-  [ship-sim world]
  =^  arfx=(list sim-ovum)  kor.sim  (poke-kernel kor.sim wen.wol ovo)
  |-
  ?~  arfx  [sim wol]
  =*  eff  i.arfx
  ?:  ?=([%behn *] wire.eff)
    =/  r  (take:~(. sim-behn behn.sim) wen.wol [wire card]:eff)
    =.  behn.sim  sim.r
    =^  sim  wol  (apply-fx who fx.r sim wol)
    $(arfx t.arfx)
  ?:  ?=([%term *] wire.eff)
    =/  r  (take:~(. sim-term term.sim) [wire card]:eff)
    =.  term.sim  sim.r
    =^  sim  wol  (apply-fx who fx.r sim wol)
    $(arfx t.arfx)
  $(arfx t.arfx)                        ::  undriven effects drop
::  +run-driver-res: an engine result: fx to world, ova to kernel
::
++  run-driver-res
  |=  [who=ship fx=(list uv-effect) ova=(list sim-ovum) sim=ship-sim wol=world]
  ^-  [ship-sim world]
  =^  sim  wol  (apply-fx who fx sim wol)
  |-
  ?~  ova  [sim wol]
  =^  sim  wol  (run-ovum who i.ova sim wol)
  $(ova t.ova)
::  monadic fleet actions
::
++  spawn
  |=  [who=ship kor=vase]
  ^-  form:m
  |=  wol=world
  =/  sim=ship-sim
    :*  kor
        nex=2
        uvh=(malt [1 [%timer ~]] ~)
        (init:sim-behn wen.wol 1)
        init:sim-term
    ==
  =/  rb  talk:~(. sim-behn behn.sim)
  =.  behn.sim  sim.rb
  =^  sim  wol  (run-driver-res who fx.rb ova.rb sim wol)
  =/  rt  talk:~(. sim-term term.sim)
  =.  term.sim  sim.rt
  =^  sim  wol  (run-driver-res who fx.rt ova.rt sim wol)
  [[%done ~] wol(fleet (~(put by fleet.wol) who sim))]
::  +inject: deliver one uv-event (or a terminal belt) to a ship
::
++  inject
  |=  [who=ship dev=drive]
  ^-  form:m
  |=  wol=world
  =/  sim  (~(got by fleet.wol) who)
  =/  r=[fx=(list uv-effect) ova=(list sim-ovum) *]
    ?-  -.dev
      %behn  =/  r  (call:~(. sim-behn behn.sim) wen.wol ev.dev)
             =.  behn.sim  sim.r
             [fx.r ova.r ~]
      %term  =/  r  (call-term term.sim ev.dev)
             =.  term.sim  sim.r
             [fx.r ova.r ~]
      %belt  =/  r  (belt:~(. sim-term term.sim) ;;(belt:dill bet.dev))
             =.  term.sim  sim.r
             [fx.r ova.r ~]
    ==
  =^  sim  wol  (run-driver-res who fx.r ova.r sim wol)
  [[%done ~] wol(fleet (~(put by fleet.wol) who sim))]
::  +call-term: term has no now-taking +call; dispatch manually
::
++  call-term
  |=  [sim=term-sim:sim-term ev=uv-event]
  ^-  res:sim-term
  ?+  -.ev  [~ ~ sim]
    %talk  talk:~(. sim-term sim)
    %news  (news:~(. sim-term sim) [wire res]:ev)
  ==
::  +warp: advance the clock, firing due timers in date order
::
++  warp
  |=  dt=@dr
  ^-  form:m
  |=  wol=world
  =/  end  (add wen.wol dt)
  |-
  ::  earliest due timer across the fleet
  ::
  =/  due=(unit [who=ship =hid wen=@da])
    %+  roll  ~(tap by fleet.wol)
    |=  [[who=ship sim=ship-sim] acc=(unit [who=ship =hid wen=@da])]
    %+  roll  ~(tap by uvh.sim)
    |=  [[=hid h=handle] acc=_acc]
    ?~  wen.h  acc
    ?:  (gth u.wen.h end)  acc
    ?:  ?&(?=(^ acc) (lte wen.u.acc u.wen.h))  acc
    `[who hid u.wen.h]
  ?~  due  [[%done ~] wol(wen end)]
  =.  wen.wol  wen.u.due
  =/  sim  (~(got by fleet.wol) who.u.due)
  =.  uvh.sim  (~(put by uvh.sim) hid.u.due [%timer ~])
  =/  r  (call:~(. sim-behn behn.sim) wen.wol [%timer-fire hid.u.due])
  =.  behn.sim  sim.r
  =^  sim  wol  (run-driver-res who.u.due fx.r ova.r sim wol)
  $(fleet.wol (~(put by fleet.wol) who.u.due sim))
::  +logs: read the effect log for a ship
::
++  logs
  |=  who=ship
  ^-  form:ml
  |=  wol=world
  :_  wol
  [%done (murn log.wol |=([w=ship f=uv-effect] ?:(=(w who) `f ~)))]
--
