{ application, al,
  [
    { description, "Arda lexical compiler" },
    { vsn, "1" },
    { modules, [ al, al_sup, dispatcher, debug,
                 lexer, gen_lexer,
                 model,
                 language, rule, sentence, word ] },
    { registered, [] },
    { applications, [ kernel, stdlib ] },
    { mod, { al_sup, [
      { log_cl, 10 },
      { log_fl, 10 },
      { log,    "al.log" },
      { ref,    "lang.qu.txt" },
      { lang,   "etc/al" },
      { src,    "priv" },
      { dst,    "priv" } ] } }
  ]
}.