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

Finding: spacing and retrieval practice have robust support. Kim and Webb (2022),
"The effects of spaced practice on second language learning: A meta-analysis",
Language Learning 72(1), 269 to 319, quantitatively examined 37 experimental studies
and confirmed a positive overall effect of spacing on L2 learning, while noting the
effect varies by learning type, learner, and practice activity, and that some
sub analyses were inconclusive due to few studies. (Correction: an earlier draft of
this note cited "48 experiments and 3,411 participants" and a blanket "medium to
large" effect; those specifics were not supported by the primary source and have
been removed.)

On algorithms: SM-2 (Wozniak, 1987, SuperMemo) is simple and deterministic; SuperMemo
reports high long term retention from its early SM-2 use, a figure from the vendor
rather than an independent trial. FSRS (2022) fits a per learner forgetting curve
with machine learning and, on the open spaced repetition benchmark, outperforms SM-2
for the large majority of users; but it needs a sizeable personal review history and
is not deterministic. These comparative figures come from SuperMemo and the FSRS
benchmark authors and are treated here as indicative, not independently verified.

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
- Kim, S. K., and Webb, S. (2022). The effects of spaced practice on second language
  learning: A meta-analysis. Language Learning, 72(1), 269 to 319.
  https://www.cambridge.org/core/product/C833408A4C3BAD939CA39EA734423BB7 (and the
  journal record). 37 experimental studies.
- SM-2: SuperMemo (Wozniak). FSRS and its benchmark: the open spaced repetition
  project. Both treated as indicative vendor or author reported figures.
- Azure Neural TTS Albanian voices sq-AL-AnilaNeural (female) and sq-AL-IlirNeural
  (male) are General Availability. Confirmed via Azure voice listings (for example
  https://json2video.com/ai-voices/azure/voices/sq-al-ilirneural/ and the Azure AI
  Speech catalog). This is the licensing path for shipped audio, still gated on
  authorization and native review.
- Apple Foundation Models and Speech documentation (verified in Phase 3/4, see
  `Documentation/Phase3_4/PHASE3_4_REPORT.md`).
