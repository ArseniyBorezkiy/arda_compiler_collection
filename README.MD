# ������������� ��������������� ����������
#### Arda compiler collection

���������� �������������� ������ ����������� ������ �� ������ ��������� ������ ����������.

������ �������� ���������� �� ������� �� ������������ ����� ���� ������ ���������������� � ���������� ������������� ��� ����������. �������� ����������� ������ ��������� ������ ������ � ������. ���������� ������� �� Erlang.

### ������ �� ����������

  - ���������� Erlang OTP 17.0
  - � priv/config.bat ��������� ������ �� ��� Erlang �����������
  - ����� �� ������ ���� ������� �������� (������� ���� � ������ �������)
  - ��������� make.bat (����������� .beam ������ � boot-script � ����� /ebin)

### ������

  - compile.bat - ��� ���������� ��� ������� �� ���������� ������
    (��������� ��� ���������� ����� ������ �������������� ��������� ������)
  - test.bat - �������� ������ ������������� �������
  - start.bat - ������ �������������� ������ �� ��������� (��� �������)
  
### ��������� �������

  ������� ������ (.in) ��� ������� �� ������ �������� � var/tests.*/
  ���������� ������� ���������� ���� �� (.out)
  ���� ������� � var/tmp

### ��� ��� ��������

  ������������ ������-��������� �����������.
  ��� ������� .bat ������ ����������:
  - ��������� ���������� ��������� (priv/config.bat)
  - ��������������� ������ (���������� cmd.exe) ��� ������� acc (priv/common.bat)
    - ACC - ������ (�������������� ����� �������� ����� �������� � ����� ��������)
    - ACCD - ��������� ������ ����������� ��� �������� ��������� (� ��������� ����������)
    - ACCS - ��������� ������ ����������� � �������� ���� � ��������� ���������� � ����� ����
    - ACCSI - ��������� ������ ����������� � �������� ���� � ��������� ��������� (� ��������� ����������)
    - ACCSD - ��������� ������ ����������� � �������� ���� ���������� ��� ��������
  
  ��� ������� ������� ���������� �������� ���� � ������� ����������� erlang ����������.
  ������ ����������� ��������� ��������� ������ ���������� � ����� � ������ � ��������� �� rpc.

  �� ������ ������ ���������� ������ ����������� ���������� (al).
  
### ��������� �������

| ���������� | ���������� |
| ------ | ------ |
| src | �������� ��� |
| include | ������������ ����� |
| priv | ��������� ������� |
| var | ������� ������ � ���������� ������� |
| var/tmp | ���� |
| ebin | ���������������� ������, ����� ����������, ����������� ������, ������������ ���� |
| etc/al | ������ ���������� ������������ ����������� |
| etc/qu | ������ ���������� ������������ ����������� ��� ����� Quenya |
| etc/lat | ������ ���������� ������������ ����������� ��� Lingua Latina |
| etc/al/tpl | ������ ������ ������������ ����������� |
| etc/as | ������ ���������� ��������������� ����������� (���� �� ������������) |
| etc/as/tpl | ������ ������ ��������������� ����������� (���� �� ������������) |

### ������ - ������ �������� ������

������, ���������� �� ������� ���� (qu / lat / tpl / ...) ��������� � ����� test.bat:
```
SET LANG=qu
```
������ ����� �������������� ����� Quenya �� var/tests.qu
���, ��������, ���������/������/��������� ������� "��������" ����� ���� �����, ��� ������� � ������������, ������������ ������������:
```
falasta    /* V.inf. V.aor. V.imp. */
```
����� ������� ������ �� ������ (var/test.qu/test.out) �� �������� ��������� ������ �����:
```
falasta {
  verb { /* 1.3.1.1.1.3.1.2.4.1.5.3.1.4.1.1.3.100. */
    avb_time = V.inf. /* infinitive */
    pars_orationis = vb. /* the verb */
    {
      mvb_stem = falasta /* voc_verbs */
      /* mvb_augment */
      /* mvb_stem_vowel */
      /* mvb_endings */
      /* mvb_time = a */
    }
  }
  verb { /* 1.3.1.1.1.3.1.2.4.1.5.3.1.4.3.1.3.100. */
    avb_time = V.imp. /* imperative */
    pars_orationis = vb. /* the verb */
    {
      mvb_stem = falasta /* voc_verbs */
      /* mvb_augment */
      /* mvb_stem_vowel */
      /* mvb_endings */
      /* mvb_time = a */
    }
  }
  verb { /* 1.3.1.1.1.3.1.2.4.1.5.3.1.4.2.1.3.100. */
    pars_orationis = vb. /* the verb */
    avb_time = V.aor. /* aorist */
    {
      mvb_stem = falasta /* voc_verbs */
      /* mvb_augment */
      /* mvb_stem_vowel */
      /* mvb_endings */
      /* mvb_time = a */
    }
  }
}
```
### ��� ������ ���������� �������?
���������� �� ����� �� ��������� ������������� � �������� ��� ������ �������������� ��������. ��������, �������� ��������� ���������� �������� "�����" � "�������" � "�������". �� ������ ���� � ��������� ������ ��������������� ������� �������� �������������� ������. �� ���� ����� ����������� ���������������. ������� ���������, ���������� ������������ ���� �� ��� ���� ��� �������� ��������� (������� � �� ���������), ��������������� �������� ������.
� ��������� ������ etc/al/tpl �������� �������� ������� ��� �������� ������� ��� ��������� ����������� ������ ���������� ������������� ����� �� ������� ������������ ��� �������� ������������� ���������� "�����" (������� ����� ����� ������� �� 5 �����).

### ������ ����� �������� ������ ���������
��� ����������� ���������� ���������� �������� ����� ���������� ������� Quenya.
������ ���� �� etc/al/qu/verb.qu
```
.class verb {
  pars_orationis
  avb_time
  avb_subject
  avb_object
  avb_ending
  avb_vowel_type
  avb_augment
  avb_augment_type
  avb_conjugation
  avb_prefix
}
```
��� ����� �� ������� ������ ������������ ����� �����, ��������������� �����. ��� ��������� ��������, �������� ������� �������� ���������� � ����������� � ������. ���, ��������, �������� �������� �������, �������� � ����� �������:
```
.attribute avb_time 2 {
  V.inf.      = "infinitive"
  V.aor.      = "aorist"
  V.imp.      = "imperative"
  V.pr.       = "present continuous"
  V.p.        = "past continuous"
  V.f.        = "future"
  V.pfct.     = "perfect"
  V.paf.      = "past future"
}

.attribute avb_augment 7 .verbose {
  V.aug.      = "augment"
  V.aug.no.   = "no augment"
}

.vocabulary voc_verbs {
  falasta  vb. VC.A
  ham      vb. VC.B
  miqu     vb. VC.U
}
```
�������, ���������� ��� ����� ��������� ����� ����. ������ ������ ���������� �������������� ������� �����������: ����� �������������� ����� ����� �������� ������� ����� �����, ������ �������� ����� ���� ��������. ��������, ������, ��������������� �� -a ����� ���� ���� ����������� (1 �������), ���� �������� (2 �������), ���� ����������� (3 �������), �� � ����� ������ � ������ ������� �� ����� ���� ��������.
```
/* verb time */

.match .backward mvb_time {
  /* A conjugation */
  -a          | VC.A V.inf.            V.aug.no.
  -a          | VC.A V.aor.            V.aug.no.
  -a          | VC.A V.imp.            V.aug.no.
  =(+a)+ea    | VC.A V.pr.   V.st.l.w. V.aug.no.
  =a+ne       | VC.A V.p.              V.aug.no.
  =(+a)+uva   | VC.A V.f.              V.aug.no.
  =(+a)+ie    | VC.A V.pfct. V.st.l.w. V.aug.
  =(+a)+umne  | VC.A V.paf.            V.aug.no.
}

.match .inward-void m_verb {
  mvb_augment mvb_stem_vowel mvb_stem mvb_time mvb_endings | vb. verb
}
```
������� ������� �������� ��� ��������, �.�. ������ ����� ���� �� ����� ����� � ������, ��� ���������� ��� ��������������� ������ � ���������� �����. � ������ ���� � ������� ����������� (������) ���������� ����������������� �������� (������ �������� ������ ��������, �������� V.aug � V.aug.no), ����� ���� ����������� ���������� ��� �����������.

### ��� ����� ������������ � ������ ����������?
- ���������� (�� ��������� �����) � ��������� ������� ���������; ��������� ������ ������.
```
.global /* lang.qu */

.include "etc.qu.txt"
.include "adj.qu.txt"
.include "noun.qu.txt"
.include "verb.qu.txt"
```
- ����������� � ������������ ������ ����� � �����������.
```
.language quenya 1 100
.compiler 1 0
```
- ��������
```
.alphabet aou_vowel {
  a   = "tehta (a)"
  o   = "tehta (o)"
  u   = "tehta (u)"
}
```
- ���������� � �������� ��������
```
.vocabulary voc_verbs ;
.vocabulary voc_verbs {
  falasta  vb. VC.A
  ham      vb. VC.B
  miqu     vb. VC.U
}

/*
 * Before definitions of how words should be recognized you can specify
 * phony rule that is equivalent to match word from specified vocabulary.
 * It is means that the rest of the word would be matched at the specified in
 * the match section order (order depends on the position and the direction,
 * see match specification for more details).
 *
 *   .vocabular   <direction> <rule> <dictionary> /* 1 */
 *   .vocabular-l <direction> <rule> <dictionary> /* 2 */
 *   .vocabular-r <direction> <rule> <dictionary> /* 3 */
 *
 * The first variant is used for exact matches (whole rest of the word).
 * The second - for left end subrest matches.
 * The third - for right end subrest matches.
 */
```
- �������
```
.mutation fvb_append_vovel_a { VOID += a }
```
- ��������� (��� �������� �����)
```
.reflection fvb_shortify_vowel {
  aa  = a
  ee  = e
  ii  = i
  oo  = o
  uu  = u
}
```
- �������������� ������� ��� ���������
```
.wildcard * vowel
.wildcard # consonant
```
- �������������� ������� ��� ������� � ���������
```
.wildcard (+a) fvb_append_vovel_a
```
- ������� ������� (� ������ ������ ����� - backward, forward � inward)
```
.match .backward ma_adverb {
  =a+ve       | AD.A
  =e+ve       | AD.E
  =ea+ve      | AD.EA
  =#+we       | AD.C
}

.match .inward-void m_adjective {
  ma_stem ma_number | adj. adjective
  ma_stem ma_adverb | adj. adverb
}

/*
 * Match specification is the powerful easy mechanism for words recognision.
 * Each regular match expression has 3 mode:
 *
 *   '=' match mode:
 *         only comparation.
 *   '+' rift mode:
 *         comparation and rifting from subword copy,
 *         appending detached part to rule 'value' field that could be
 *         found in the output generated files.
 *   '-' hold mode (comparation and holding)
 *         comparation and holding (not detaching),
 *         appending holded part to rule 'value' field that could be
 *         found in the output generated files.
 *
 * Here we are using mutations. Mutations applicable to the edge of the
 * current subword copy only.
 *
 * Example:               /* meaning */
 *   -u(*>o)=e            /* vowel 'u' following vowel 'e'
 *                           ('ue' -> 'oe' for '.forward' rules)
 *                           ('ue' -> 'uo' for '.backward' rules) */
 *   -u(a>aa,o>oo)(*>o)=e /* vowel 'u' following by vowel 'e'
 *                           ('ue' -> never match for '.forward' rules)
 *                           ('ue' -> 'uoo' for '.backward' rules) */
 */
```
- ������ ������� (target) � �������� ���������� ������
```
.match .inward-void main {
  m_noun
  m_adjective
  m_verb
}

.target main
```

### ��� ����� ������ ����������?
�� ����� ��������� ����������� ������ �� ���������� �������������� ���������������� ����������� � ����� �������� ������ ���������. ����� ����� ���������� ���������� � ��������� ������ etc/al/tpl

### ������� � �����������
������ ��������������? ������ �� apborezkiy@gmail.com
