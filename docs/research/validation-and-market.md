# Research, Validation, and Market

## Research rationale

VibeProof is based on a work-sample hypothesis: job-relevant simulations can provide evidence that resumes, self-report, and unverified submissions cannot provide on their own.

The supplied research and external literature support exploring structured work samples and gamefully designed assessments, but they do not establish that this prototype is already valid, reliable, fair, or predictive.

Relevant research:

- [A meta-analysis of work sample test validity](https://onlinelibrary.wiley.com/doi/pdf/10.1111/j.1744-6570.2005.00714.x)
- [Game-related assessments for personnel selection: A systematic review](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.952002/full)
- [Game-based, gamified, and gamefully designed assessments for employee selection](https://doi.org/10.1111/ijsa.12376)
- [Serious games in high-stakes assessment contexts](https://link.springer.com/article/10.1007/s11423-024-10362-0)

Current product hypothesis:

> Observable decisions during a controlled AI-assisted engineering incident can provide useful early evidence of understanding, verification, adaptation, and ownership beyond a resume or unverified code submission.

This hypothesis requires validation against expert ratings, equivalent scenarios, fairness outcomes, and real hiring workflows.

## Psychology-informed design

Psychological constructs provide design vocabulary, not a license to assign traits.

### Metacognition

Ask for confidence before and after important evidence. Observe whether the candidate expresses uncertainty and updates confidence appropriately.

### Automation bias

Provide a plausible but incomplete or flawed AI suggestion. Observe whether the candidate inspects assumptions and verifies the recommendation.

Reference: [Parasuraman and Riley, 1997](https://doi.org/10.1518/001872097778543886)

### Cognitive flexibility

Introduce evidence that challenges the initial hypothesis. Observe whether the candidate adapts rather than defending the first answer.

Reference: [Miyake et al., 2000](https://www.sciencedirect.com/science/article/abs/pii/S001002859990734X)

### Cognitive forcing functions

Before submission, require the candidate to identify a possible failure mode, state confidence, inspect or run a relevant test, and explain the decision.

Reference: [Bucinca et al.](https://arxiv.org/abs/2102.09692)

These mechanics produce observable evidence. They do not measure neural activity, diagnose cognition, or establish stable personal characteristics.

## Market hypothesis

Malaysia has credible interest in AI capability and workforce transformation, but that does not prove demand for a new assessment product.

Existing market signals include:

- [Jobstreet Hiring, Compensation and Benefits Report 2025](https://my.jobstreet.com/about/news/article/hiring-compensation-benefits-report-2025), which reported employer interest in AI capability alongside adoption and trust concerns.
- [TalentCorp Impact Study](https://www.talentcorp.com.my/impact-study/), which describes AI- and digital-driven workforce changes across Malaysian sectors.

The initial market hypothesis is:

> Some Malaysian hiring teams need a short and understandable way to verify AI-assisted engineering ownership without adopting a large enterprise assessment programme.

The strongest segment to test first is junior, graduate, internship, or intermediate engineering hiring where application volume is meaningful, portfolio or take-home work is common, and technical interviewer time is constrained.

## Competitor context

Codility and CodeSignal are established assessment platforms. VibeProof must not claim that AI-assisted assessment, process evidence, realistic tasks, or reports are unique.

| Area | Codility | CodeSignal | VibeProof hypothesis |
|---|---|---|---|
| Primary object | Platform or employer-authored task | Certified assessment or role simulation | Candidate-claimed or controlled artifact |
| Environment | Full development environment and tools | Browser IDE and simulations | Short incident workspace |
| AI | Configurable assistant and captured activity | AI-assisted assessments and interviews | AI allowed; ownership tested through verification |
| Output | Structured skills evidence and reports | Scores, reports, and interview evidence | Chronological Proof Replay |
| Proposed position | Full technical assessment platform | Broad skills assessment platform | Verification step before human interview |

Official sources:

- [Codility AI-Native Tasks](https://www.codility.com/ai-native-tasks/)
- [Codility custom content with MCP](https://support.codility.com/hc/en-us/articles/45339349251345-Creating-Your-Own-Content-Build-with-MCP)
- [CodeSignal role-based simulations](https://codesignal.com/simulations/)
- [CodeSignal self-service hiring plans](https://support.codesignal.com/hc/en-us/articles/39317753035287-Getting-Started-with-CodeSignal-Hire-Build-Grow)
- [CodeSignal product updates](https://support.codesignal.com/hc/en-us/articles/40894675893655-Product-Updates-May-2026)

Potential employers that need a complete, validated platform may be better served by an incumbent. VibeProof's narrower position must be tested with real buyers.

## Unvalidated assumptions

1. Hiring teams frequently receive AI-assisted portfolios or take-home work that they struggle to verify.
2. A 10- to 15-minute Ownership Challenge is acceptable to candidates.
3. A Proof Replay is more useful to reviewers than a single score.
4. Reviewers will change interview questions or screening decisions based on the evidence.
5. Artifact-grounded challenges can remain comparable across candidates.
6. Local context, bilingual access, and small-team pricing influence adoption.
7. Employers will pay for verification instead of using a short live call.
8. The homepage-latency scenario produces meaningful differences between experience levels.

## Validation plan

### Customer discovery

- Interview at least five Malaysian technical recruiters or engineering managers.
- Discuss the last real hire and current workflow rather than asking only whether the concept sounds useful.
- Obtain repeated confirmation of the same painful problem.
- Secure at least two commitments to test a representative pilot.
- Record current reviewer time and compare it with the VibeProof workflow.

### Assessment validation

- Define competencies through job analysis and experienced-engineer interviews.
- Ask independent senior engineers to rate the same sessions.
- Measure reviewer agreement.
- Create equivalent scenario variants and compare difficulty.
- Compare candidate evidence patterns across experience levels.
- Test repeatability where appropriate.
- Audit language, device, accessibility, gaming experience, and AI familiarity effects.
- Study whether the report improves later interview quality.
- Compare results with job outcomes only after appropriate consent, governance, and study design.

These are early research steps, not proof of product-market fit or assessment validity.

## Regulatory and fairness considerations

Malaysia's [Automated Decision-Making and Profiling Guideline](https://www.pdp.gov.my/ppdpv1/wp-content/uploads/2026/04/Automated-Decision-Making-And-Profiling-Guideline-ADMP.pdf) uses employment ranking and shortlisting as examples with potentially significant effects.

VibeProof should therefore provide:

- clear notice and purpose limitation;
- explicit evidence collection and retention rules;
- consent and access controls;
- transparent rubric-linked evidence;
- technical-error and accommodation handling;
- human review;
- a path to question or correct relevant data;
- validation and fairness monitoring before high-stakes deployment.

## Sources

The historical archive preserves the supplied Miro export, original research PDF, earlier product documents, platform exploration, and product debates. Archived files provide provenance but are not canonical product guidance.

Use [VibeProof Product Decisions](../decisions.md) to resolve conflicts between archived research and the current direction.
