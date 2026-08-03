/-  spider, eval=ted-eval
/+  strandio
=,  strand=strand:spider
^-  thread:spider
|=  raw=vase
=/  m  (strand ,vase)
^-  form:m
=+  !<(arg=(unit inpt:eval) raw)
?~  arg
  (strand-fail:strand %no-input ~)
?@  u.arg
  ?~  u.arg
    (strand-fail:strand %no-command ~)
  (eval-hoon:strandio (ream u.arg) ~)
?~  p.u.arg
  (strand-fail:strand %no-command ~)
;<  =beak  bind:m  get-beak:strandio
=/  paz=(list path)  q.u.arg
=/  bez=(list beam)  ~
|-
?~  paz
  (eval-hoon:strandio (ream p.u.arg) bez)
=/  bem
  %+  fall
    (bind (de-bema i.paz) bema-to-beam)
  [beak i.paz]
;<  has=?  bind:m  (check-for-file:strandio bem)
?.  has
  (strand-fail:strand %no-file >bem< ~)
$(paz t.paz, bez [bem bez])
