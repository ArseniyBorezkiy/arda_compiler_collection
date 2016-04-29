{ application, acc,
  [
    { description, "Arda lexical compiler" },
    { vsn, "1.0" },
    { modules, [ acc_debug, acc_resources,
                 acc, acc_sup, acc_dispatcher, 
                 acc_lexer, gen_acc_lexer,
                 gen_acc_storage, am_ensure, am_entity, am_lrule, am_voc,
                 al_model, al_language, al_rule, al_sentence, al_word,
                 as_model ] },
    { registered, [] },
    { applications, [ kernel, stdlib ] },
    { mod, { acc_sup, [
      { lang, "en" },
      { log_cl, 10 },
      { log_fl, 2 },
      { log_dir, "var/tmp" },
      { ref_dir, "etc/al" },
      { src_dir, "var" },
      { dst_dir, "var" } ] } }
  ]
}.