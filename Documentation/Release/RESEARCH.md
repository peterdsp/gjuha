# Gjuha Product Research and Direction

Timeboxed discovery, 2026-10-03. Primary and recent secondary sources, with the
implementation decision each finding supports. Reviews are treated as qualitative
evidence, not proof of universal demand.

## Market and learner needs

Finding: Albanian has no Duolingo course. The practical alternatives are
template driven multi language apps (Ling, uTalk, 50Languages, LingoHut) plus
Pimsleur for audio. Ling is the strongest, built by native speakers with eight
game types and normal and slow audio. Pimsleur is audio and pronunciation first.
(Sources below, dated 2025 to 2026.)

Decision: compete on what template apps do not do well for a serious adult learner:
durable retention, honest progress, Standard Albanian with labeled regional
awareness, grounded grammar explanation, and an offline-first native iOS feel.
Do not reskin a generic competitor.

Uncertainty: app store reviews are qualitative. We do not claim universal demand.
The diaspora, partners and families, newcomers, and travelers are plausible
segments; the design serves adults who want to actually remember what they study.

## Learning science

Finding: spacing and retrieval practice have robust support. Kim and Webb (2022)
meta analysis, 48 experiments and 3,411 participants, found medium to large effects
of spaced practice on second language learning, with longer intervals giving the
strongest delayed retention. SM-2 (Wozniak, 1987) reached about 92 percent retention
in long term self study and is simple and deterministic. FSRS (2022) fits a per
learner forgetting curve with machine learning and beats SM-2 for the large majority
of users, but it needs a large personal review history and is not deterministic.

Decision: implement an SM-2 derived scheduler now. It is deterministic (so it is
unit testable with a fixed clock), offline, and well understood. Keep the scheduler
behind a small protocol boundary so FSRS can replace it later without touching the
feature layer. Use retrieval practice (the learner produces the answer) rather than
recognition only, which the exercise engine already supports.

## Apple platform constraints (verified, primary sources, carried from Phase 3/4)

- Apple Foundation Models (on device, iOS 26+) support only the Apple Intelligence
  language set; Albanian is not supported, and safety guardrails apply only to
  supported languages. So the app never generates authoritative Albanian with the
  model. Grammar coaching is English only, grounded in reviewed dataset Albanian,
  with a deterministic offline fallback.
- Apple Speech (`SFSpeechRecognizer.supportedLocales()`) does not include Albanian,
  and there is no Albanian system TTS voice. Confirmed at runtime by test
  `appleSpeechProbeConfirmsAlbanianUnsupported`. So no on device Albanian ASR or
  synthetic listening audio. Speaking assessment stays disabled.

## Albanian specifics

- Orthography: ë and ç are distinct letters, not accents. Dropping them changes the
  word, so grading treats a dropped diacritic as a near miss (recognized, not
  accepted) with a targeted hint. This is already enforced by `AnswerNormalizer`.
- Standard Albanian (based on Tosk) is the taught variety. Gheg content is labeled
  and held for native review rather than mixed in silently.

## Sources

- https://www.langoly.com/albanian-apps
- https://www.alllanguageresources.com/learn-albanian-app/
- https://ling-app.com/blog/best-apps-to-learn-albanian/
- Kim and Webb (2022), meta analysis of spaced practice in L2 learning (reported via
  https://riset.unisma.ac.id/index.php/JREALL/article/view/25562 systematic review)
- SM-2 and FSRS overview: https://www.mindomax.com/fsrs-vs-sm2-spaced-repetition-algorithm
- Apple Foundation Models and Speech documentation (verified in Phase 3/4, see
  `Documentation/Phase3_4/PHASE3_4_REPORT.md`).
