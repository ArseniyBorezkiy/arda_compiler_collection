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
      { log_fl, 2 },
      { log_dir, "var/tmp" },
      { ref_dir, "etc/al" },
      { src_dir, "var" },
      { dst_dir, "var" } ] } }
  ]
}.