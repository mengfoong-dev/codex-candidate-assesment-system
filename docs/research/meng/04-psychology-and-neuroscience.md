# Psychology and Neuroscience Foundation

## Core principle

The game can observe behavior associated with psychological constructs. It cannot directly read thoughts, measure brain activity, or prove what happened inside a candidate's brain.

## Executive functions

Executive functions relevant to software incidents include:

- Working-memory updating: tracking requirements, constraints, and new evidence
- Cognitive flexibility: changing plans when the incident changes
- Inhibitory control: resisting a tempting but unsafe AI recommendation

Miyake et al. studied the separability and relationship of shifting, updating, and inhibition as executive functions. These constructs provide a useful design vocabulary, not a direct scoring license. [Miyake et al., 2000](https://www.sciencedirect.com/science/article/abs/pii/S001002859990734X)

## Metacognition

Metacognition means monitoring and evaluating one's own knowledge or performance. KerjaProof can operationalize this through confidence estimates before and after evidence.

Useful observable signals:

- Confidence before testing
- Confidence after test results
- Willingness to request information
- Ability to explain uncertainty
- Willingness to revise a decision

## Automation bias

Automation bias describes over-reliance on automated recommendations and insufficient monitoring of their limitations. This is directly relevant to AI-generated code. [Parasuraman and Riley, 1997](https://doi.org/10.1518/001872097778543886)

KerjaProof can test this by providing a plausible but flawed AI patch.

## Cognitive forcing functions

Before deployment, require the candidate to:

1. Identify a possible failure mode.
2. State confidence in the patch.
3. Run or inspect a relevant test.
4. Decide whether to deploy.

This design creates useful reflective friction and makes verification observable. Research on cognitive forcing functions has examined ways to reduce over-reliance on AI recommendations. [Buçinca et al.](https://arxiv.org/abs/2102.09692)

## Error monitoring and correction

Neuroscience reviews associate medial prefrontal and anterior cingulate systems with performance monitoring, error detection, conflict resolution, response correction, and feedback evaluation. [Performance monitoring review](https://pmc.ncbi.nlm.nih.gov/articles/PMC3394443/)

For KerjaProof, the defensible translation is:

```text
Candidate action → new evidence → error detection → correction or escalation
```

Do not claim:

- The game measures the anterior cingulate cortex.
- The game measures brain activity.
- The game diagnoses intelligence or personality.
- The game predicts job success without validation.

## Psychology-informed measurement matrix

| Job-relevant behavior | Psychological construct | Observable signal |
|---|---|---|
| Checks AI output before deployment | Metacognition / automation-bias resistance | Inspection and test actions |
| Updates plan after failed test | Cognitive flexibility | Change in decision after evidence |
| Tracks constraints across tasks | Working-memory updating | Requirement and edge-case coverage |
| Notices the hidden bug | Error monitoring | Defect identification |
| Explains uncertainty | Metacognitive awareness | Confidence and rationale |

## Fairness considerations

Do not score:

- Typing speed as intelligence
- Mouse movement as personality
- Gamer reflexes
- Facial expressions
- Voice accent
- Unrelated stress behavior

Keep interaction keyboard-and-mouse accessible, support English and Bahasa Melayu, and make the task instructions explicit.
