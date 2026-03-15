## Health Score

A single **0–100 number** computed from violation count and impact severity.

| Band | Score | Meaning |
|------|-------|---------|
| Green | 80–100 | Good shape — few issues, none critical |
| Yellow | 50–79 | Needs work — some high-impact issues |
| Red | Below 50 | Serious problems — many critical violations |

The **status bar** shows the score with a delta from the last run (e.g. "Saropa: 78 ▲4").

Critical issues penalize heavily, minor issues less so — the score reflects *business impact*, not just issue count.
