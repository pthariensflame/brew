---
last_review_date: "2026-10-14"
---

# Description Guidelines

The `desc` stanza is a one-line description of the software a formula or cask installs.
Homebrew prints it next to the package name in `brew info`, `brew desc` and `brew search --desc`, and on [formulae.brew.sh](https://formulae.brew.sh).
The same guidelines apply to formulae and casks.
They cover what needs judgement; `brew style --fix` handles mechanical details such as length and capitalisation.

## Describe, don't sell

A description answers one question for someone who has never heard of the software: what is it?
Answer as a neutral third party would, in the plain words someone might search for.
The upstream homepage is a reasonable starting point, but it was written to persuade, so expect to cut most of it.

```diff
- desc "Development of musical ideas made easy"
+ desc "Sound and music editor"
```

A good description says what the software is or does, makes sense on its own next to the package name and fits comfortably on one line.
It does not need to be exhaustive or unique.
"Sound and music editor", "HTTP(S) server and reverse proxy" and "Vim plugin manager" are all fine.

## What to leave out

* **Marketing language.**
  Adjectives such as "modern", "powerful", "lightweight" and "beautiful" describe nothing; no software calls itself outdated and bulky.
  Cut them, along with slogans and taglines.

  ```diff
  - desc "Beautiful and powerful modern sound and music editor"
  + desc "Sound and music editor"
  ```

* **Feature lists.**
  A description is a summary, not a changelog.
  Say what the software is for and leave the details to the homepage.

  ```diff
  - desc "Sound and music editor with effects, instruments, loops, MIDI and plugin support"
  + desc "Sound and music editor"
  ```

* **Comparisons with other projects.**
  Describe the software by what it does, not by what it replaces or resembles.
  "Alternative to", "replacement for" and "like X but faster" borrow another project's reputation instead of saying anything about this one.
  Naming another project is fine when the relationship is a fact rather than a pitch, e.g. "Slack client", "Vim plugin manager" or "Fork of X with Y support".

  ```diff
  - desc "Faster, open-source alternative to Ableton Live"
  + desc "Sound and music editor"
  ```

* **Addressing the reader.**
  Describe the software rather than telling people what they can do with it.

  ```diff
  - desc "Edit your music files"
  + desc "Sound and music editor"
  ```
