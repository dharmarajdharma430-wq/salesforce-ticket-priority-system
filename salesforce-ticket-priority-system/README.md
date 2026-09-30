# Customer Support Ticket Priority Prediction + Auto-Assignment (Salesforce)

Rule-based, Salesforce-native system that predicts `Case.Priority` from Subject/Description
(+ optional Account tier) and auto-routes to Queue/Team with SLA + escalation.
No Einstein / external ML required. Includes offline simulator so you can demo **without an org**.

## How it works

```
Case (Subject + Description)
  → TicketPriorityPredictor.predict() → Priority (Critical/High/Medium/Low) + score + reason
  → TicketAssignmentService.assign()  → Queue + Team + SLA hours + escalated flag
  → CaseTriggerHandler (before insert/update) sets fields on Case
```

**Scoring** (`TicketPriorityPredictor.cls` — mirrored in `scripts/simulate.py`):
- Critical keywords +30: outage, down, data loss, breach, security, production down, sla breach, system down
- High keywords +15: urgent, critical, escalat, unable to work, payment fail, cannot access, blocked
- Medium keywords +5: slow, error, issue, delay, bug, broken, failing
- Low indicators −10: question, how to, feature request, documentation, training, suggestion
- Tier bonus: Platinum +20, Gold +10, Silver +5
- Thresholds: ≥50 Critical, ≥30 High, ≥10 Medium, else Low

**Routing** (`TicketAssignmentService.cls`):
| Priority | Queue | SLA | Escalated |
|---|---|---|---|
| Critical | Critical_Support_Queue | 1h | true |
| High | Senior_Support_Queue | 4h | false |
| Medium | General_Support_Queue | 24h | false |
| Low | Junior_Support_Queue (or `<Team>_Queue` on skill match) | 72h | false |

Skill detect: billing/invoice/refund/payment → Billing_Team;
security/breach/login/access → Security_Team;
outage/api/integration/error/down → Technical_Team.

## Try it without an org (2 min)

```bash
cd salesforce-ticket-priority-system
python scripts/simulate.py
# python scripts/simulate.py --input data/sample_cases.csv
```

Expected: `Accuracy: 20/20 = 100%` on synthetic data + per-ticket queue/team table.
`scripts/simulate.py` is a line-for-line mirror of the Apex — keep them in sync when tuning.

> Known rule-based limit: row 17 ("Urgent outage? No — how to question") scores Medium
> because negation isn't handled. Fix by adding negation handling, tuning keywords,
> or upgrading to Einstein Prediction Builder / an ML model later.

## Deploy to a real org

1. Create a Developer org (if you don't have one):
   ```bash
   sf org create scratch -f config/project-scratch-def.json -a ticket-demo -d
   # or: sf org login web -a myOrg
   ```
2. (Optional but recommended) Create custom fields on Case:
   `Team__c` (Text), `SLA_Hours__c` (Number), `Priority_Score__c` (Number),
   `Routing_Reason__c` (Long Text) — then uncomment the 4 `c.put(...)` lines
   in `CaseTriggerHandler.cls`.
3. Create real Queues matching the names in `TicketAssignmentService.cls`
   (Setup → Queues) or edit the class to your DeveloperNames.
4. Deploy + test:
   ```bash
   sf project deploy start -d force-app -o myOrg
   sf apex run test -n TicketPriorityPredictorTest -o myOrg -w 10
   ```
5. Load sample data: import `data/sample_cases.csv` as Cases (Data Import Wizard),
   then verify Priority/Team/SLA auto-populate.

## Project layout

```
sfdx-project.json
force-app/main/default/
  classes/TicketPriorityPredictor.cls (+ test + meta files)
  classes/TicketAssignmentService.cls
  classes/CaseTriggerHandler.cls
  triggers/CaseTrigger.trigger
data/sample_cases.csv        # 20 synthetic tickets with expected priorities
scripts/simulate.py          # offline mirror of Apex logic
```

## Tuning / next steps

- Edit keyword lists + thresholds in `TicketPriorityPredictor.cls` (and mirror in `simulate.py`).
- Move routing table to Custom Metadata (`Ticket_Routing__mdt`) for admin editing.
- Add round-robin Owner assignment via Queue members or Omni-Channel.
- Upgrade path: replace `predict()` internals with an Einstein Prediction Builder
  callout or external ML endpoint — trigger/handler contract stays the same.
