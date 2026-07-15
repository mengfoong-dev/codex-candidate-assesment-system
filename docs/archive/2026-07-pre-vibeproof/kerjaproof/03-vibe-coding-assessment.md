# Vibe Coding and Technical Assessment

## Reframed problem

The question should not be:

> Did the candidate use AI to write the code?

The better question is:

> Can the candidate responsibly direct, verify, debug, test, and maintain AI-assisted code?

## Why AI-use detection is the wrong product

AI-generated code can be modified by a human, human-written code can look machine-generated, and candidates may use AI appropriately. A detector would create false positives and encourage an adversarial hiring process.

KerjaProof should evaluate ownership of the engineering outcome.

## Mini-game: Patch & Ship

### Game state

The candidate has:

- A small codebase
- Error logs
- Test results
- Customer-impact information
- An AI-generated pull request
- A deployment button
- A rollback option
- A team communication panel

### Candidate actions

- Inspect the code
- Ask the AI for a patch
- Challenge the AI suggestion
- Run tests
- Add or select an edge-case test
- Deploy
- Roll back
- Ask for information
- Explain the decision

### Tracked behavior

- Whether the candidate inspects before accepting AI output
- Whether the candidate tests before deployment
- Whether the candidate notices requirement conflicts
- Whether the candidate detects hidden defects
- Whether the candidate adapts after new evidence
- Whether the candidate manages customer and security risk
- Whether confidence changes after test feedback

## Confidence calibration mechanic

Before seeing test results, ask the candidate to estimate confidence in the patch.

After testing, ask for an updated confidence estimate.

```text
High confidence + incorrect patch = possible overconfidence
Low confidence + correct patch = possible underconfidence
Confidence changes appropriately after evidence = good calibration
```

This measures metacognitive calibration within the scenario. It does not diagnose a personality trait or permanent ability.

## Scoring approach

Start with deterministic rules. Do not depend on a complex machine-learning model for the hackathon.

```text
+10  Inspects the AI patch before accepting it
+10  Runs tests before deployment
+10  Checks a relevant edge case
+10  Identifies customer impact
+10  Uses rollback appropriately
-15  Deploys untested AI-generated code
-15  Ignores a failed test
```

For written responses, use a constrained rubric for clarity, risk awareness, and technical reasoning. Return a score, evidence, and confidence rather than a generic personality label.

## Responsible wording

Use:

> KerjaProof observes engineering ownership during an AI-assisted work simulation.

Avoid:

> KerjaProof knows how the candidate thinks.

Avoid:

> KerjaProof detects cheating or predicts future job performance.
