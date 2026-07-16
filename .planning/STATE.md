# Project State

## Current milestone

v1.0.0 — Cohere Command A+ live-flow migration.

## Current status

Implementation and automated verification are recorded in
`reports/MILESTONE_SUMMARY-v1.0.0.md`. The latest recovery removed the rejected Cohere `thinking`
request field, and the live five-turn candidate run completed with sandbox read/write actions,
scripted checks, and a Layer 1/2/3 report. The remaining operational follow-up is the existing
post-deployment proxy smoke test using rotated Cohere credentials and, if required, an explicit
provider-disable mode for the final-state driver.
