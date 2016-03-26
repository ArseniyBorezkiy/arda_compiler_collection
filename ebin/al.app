{ application, al,
  [
    { description, "Arda lexical compiler" },
    { vsn, "1" },
    { modules, [ al, al_sup, debug ] },
    { registered, [] },
    { applications, [ kernel, stdlib ] },
    { mod, { al_sup, [ "al.log" ] } }
  ]
}.