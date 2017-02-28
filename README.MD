# Универсальный лингвистический анализатор
#### Arda compiler collection

Производит грамматический разбор переданного текста на основе указанной сводки грамматики.

Формат описания грамматики не требует от пользователя каких либо знаний программирования и разработан исключительно для лингвистов. Частично реализованы сводки грамматик языков Квенья и Латынь. Анализатор написан на Erlang.

### Сборка из исходников

  - Установить Erlang OTP 17.0
  - В priv/config.bat поправить ссылку на ваш Erlang дистрибудив
  - запустить make.bat (сгенерирует .beam модули и boot-script в папке /ebin)

### Запуск

  - compile.bat - сам анализатор для запуска из коммандной строки
    (запустите без аргументов чтобы узнать поддерживаемые параметры вызова)
  - test.bat - пакетный анализ заготовленных текстов
  - start.bat - анализ заготовленного текста по умолчанию (для отладки)
  
### Результат анализа

  Входные тексты (.in) для каждого из языков хранятся в var/tests.*/
  Результаты анализа помещаются туда же (.out)
  Логи пишутся в var/tmp

### Как это работает

  Используется клиент-серверная архитектура.
  При запуске .bat файлов происходит:
  - Настройка переменных окружения (priv/config.bat)
  - Устанавливаются алиасы (переменные cmd.exe) для запуска acc (priv/common.bat)
    - ACC - клиент (неограниченное число клиентов могут работать с одним сервером)
    - ACCD - запускает сервер транслятора без оболочки синхронно (с ожиданием завершения)
    - ACCS - запускает сервер транслятора с конфигом ноды с оболочкой асинхронно в новом окне
    - ACCSI - запускает сервер транслятора с конфигом ноды с оболочкой синхронно (с ожиданием завершения)
    - ACCSD - запускает сервер транслятора с конфигом ноды асинхронно без оболочки
  
  При запуске сервера происходит создание ноды в которую загружается erlang приложение.
  Сервер транслятора загружает указанную сводку грамматики и готов к работе с клиентами по rpc.

  На данный момент реализован только лексический анализатор (al).
  
### Структура проекта

| Директория | Назначение |
| ------ | ------ |
| src | Исходный код |
| include | Заголовочные файлы |
| priv | Служебные батники |
| var | Входные тексты и результаты анализа |
| var/tmp | Логи |
| ebin | Скомпилированные модули, файлы приложения, загрузочный скрипт, конфигурация ноды |
| etc/al | Сводки грамматики лексического анализатора |
| etc/qu | Сводки грамматики лексического анализатора для языка Quenya |
| etc/lat | Сводки грамматики лексического анализатора для Lingua Latina |
| etc/al/tpl | Шаблон сводки лексического анализатора |
| etc/as | Сводки грамматики синтаксического анализатора (пока не используется) |
| etc/as/tpl | Шаблон сводки синтаксического анализатора (пока не используется) |

### Пример - запуск пакетных тестов

Строка, отвечающая за текущий язык (qu / lat / tpl / ...) находится в файле test.bat:
```
SET LANG=qu
```
Значит будут использоваться тесты Quenya из var/tests.qu
Так, например, инфинитив/аорист/императив глагола "пениться" имеет одну форму, что указано в комментариях, игнорируемых анализатором:
```
falasta    /* V.inf. V.aor. V.imp. */
```
После запуска тестов на выходе (var/test.qu/test.out) мы получили подробный анализ слова:
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
### Как читать результаты анализа?
Анализатор не имеет ни малейшего представления о глаголах или других грамматических понятиях. Сущности, которыми оперирует анализатор являются "Класс" и "Атрибут" и "Правило". На основе этих и некоторых других вспомогательных понятий строится грамматическая сводка. За счет этого достигается универсальность. Поэтому результат, выдаваемый анализатором есть не что иное как иерархия сущностей (классов и их атрибутов), удовлетворяющих правилам сводки.
В шаблонной сводке etc/al/tpl довольно детально описаны все основные правила для написания собственной сводки грамматики произвольного языка на примере вымышленного для удобства инопланетного микроязыка "ололо" (который легко можно освоить за 5 минут).

### Основы языка описания сводок грамматик
Для наглядности рассмотрим выборочное описание части грамматики глагола Quenya.
Пример взят из etc/al/qu/verb.qu
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
Как видно из примера глагол представляет собой класс, самостоятельную часть. Все остальные свойства, присущие глаголу являются атрибутами и перечислены в классе. Так, например, выглядит описание времени, аугмента и части словаря:
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
Правила, определяют как может выглядить часть речи. Каждая строка определяет альтернативную цепочку рассуждений: слева разделительной черты маска текущего остатка части слова, справа присущие части речи атрибуты. Например, глагол, заканчивающийся на -a может быть либо инфинитивом (1 строчка), либо аористом (2 строчка), либо императивом (3 строчка), но в любом случае у такого глагола не может быть аугмента.
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
Правило времени помечено как обратное, т.е. разбор будет идти от конца слова к началу, что характерно для агглютенативных языков с элементами фузии. В случае если в цепочке рассуждений (правил) встретятся взаимоисключающие свойства (разные значения одного атрибута, например V.aug и V.aug.no), такая цепь рассуждений отсекается как невозможная.

### Что можно использовать в сводке грамматики?
- Глобальные (за пределами файла) и локальные области видимости; включение других файлов.
```
.global /* lang.qu */

.include "etc.qu.txt"
.include "adj.qu.txt"
.include "noun.qu.txt"
.include "verb.qu.txt"
```
- Минимальные и максимальные версии языка и транслятора.
```
.language quenya 1 100
.compiler 1 0
```
- Алфавиты
```
.alphabet aou_vowel {
  a   = "tehta (a)"
  o   = "tehta (o)"
  u   = "tehta (u)"
}
```
- Объявления и описания словарей
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
- Мутации
```
.mutation fvb_append_vovel_a { VOID += a }
```
- Отражения (для эмуляции фузий)
```
.reflection fvb_shortify_vowel {
  aa  = a
  ee  = e
  ii  = i
  oo  = o
  uu  = u
}
```
- Подстановочные символы для алфавитов
```
.wildcard * vowel
.wildcard # consonant
```
- Подстановочные символы для мутаций и отражений
```
.wildcard (+a) fvb_append_vovel_a
```
- Правила разбора (с разных сторон слова - backward, forward и inward)
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
- Первое правило (target) с которого начинается разбор
```
.match .inward-void main {
  m_noun
  m_adjective
  m_verb
}

.target main
```

### Где взять больше информации?
На хабре регулярно публикуются статьи по разработке универсального лингвистического анализатора и языку описания сводок грамматик. Также много информации содержится в шаблонной сводке etc/al/tpl

### Вопросы и предложения
Хотите присоединиться? Пишите на apborezkiy@gmail.com
