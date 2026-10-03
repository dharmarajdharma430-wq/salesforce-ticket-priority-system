"""
Local simulator — mirrors TicketPriorityPredictor.cls + TicketAssignmentService.cls
exactly, so you can demo/validate the system WITHOUT a Salesforce org.

Usage:
    python scripts/simulate.py
    python scripts/simulate.py --input data/sample_cases.csv
"""
import argparse
import csv
import os
import sys

CRITICAL_KW = ["outage", "down", "data loss", "breach", "security",
               "production down", "sla breach", "system down"]
HIGH_KW = ["urgent", "critical", "escalat", "unable to work",
           "payment fail", "cannot access", "blocked"]
MEDIUM_KW = ["slow", "error", "issue", "delay", "bug", "broken", "failing"]
LOW_KW = ["question", "how to", "feature request", "documentation",
          "training", "suggestion"]


def predict(subject, description, account_tier):
    text = f"{subject or ''} {description or ''}".lower()
    score = 0
    hits = []
    for kw in CRITICAL_KW:
        if kw in text:
            score += 30
            hits.append(f"CRITICAL:{kw}")
    for kw in HIGH_KW:
        if kw in text:
            score += 15
            hits.append(f"HIGH:{kw}")
    for kw in MEDIUM_KW:
        if kw in text:
            score += 5
            hits.append(f"MED:{kw}")
    for kw in LOW_KW:
        if kw in text:
            score -= 10
            hits.append(f"LOW:{kw}")
    tier = (account_tier or "").lower()
    if tier == "platinum":
        score += 20
        hits.append("TIER:platinum+20")
    elif tier == "gold":
        score += 10
        hits.append("TIER:gold+10")
    elif tier == "silver":
        score += 5
        hits.append("TIER:silver+5")

    if score >= 50:
        priority = "Critical"
    elif score >= 30:
        priority = "High"
    elif score >= 10:
        priority = "Medium"
    else:
        priority = "Low"
    reason = f"score={score} | " + (", ".join(hits) if hits else "no match, defaulted to Low")
    return priority, score, reason


def assign(priority, subject, description):
    text = f"{subject or ''} {description or ''}".lower()
    team = "General"
    if any(k in text for k in ("billing", "invoice", "refund", "payment")):
        team = "Billing_Team"
    elif any(k in text for k in ("security", "breach", "login", "access")):
        team = "Security_Team"
    elif any(k in text for k in ("outage", "api", "integration", "error", "down")):
        team = "Technical_Team"

    p = priority or "Low"
    if p == "Critical":
        return "Critical_Support_Queue", team, 1, True
    if p == "High":
        return "Senior_Support_Queue", team, 4, False
    if p == "Medium":
        return "General_Support_Queue", team, 24, False
    q = f"{team}_Queue" if team != "General" else "Junior_Support_Queue"
    return q, team, 72, False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=os.path.join("data", "sample_cases.csv"))
    args = ap.parse_args()
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = args.input if os.path.isabs(args.input) else os.path.join(base, args.input)
    if not os.path.exists(path):
        print(f"Input not found: {path}")
        sys.exit(1)

    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    correct = 0
    checkable = 0
    print(f"{'ID':<4}{'PRED':<9}{'EXP':<9}{'SCORE':<7}{'QUEUE':<26}{'TEAM':<16}SUBJECT")
    print("-" * 120)
    for r in rows:
        pred, score, reason = predict(r.get("subject"), r.get("description"), r.get("account_tier"))
        queue, team, sla, esc = assign(pred, r.get("subject"), r.get("description"))
        exp = (r.get("expected_priority") or "").strip()
        mark = ""
        if exp:
            checkable += 1
            if pred == exp:
                correct += 1
                mark = "OK"
            else:
                mark = f"MISMATCH ({reason})"
        print(f"{r.get('id',''):<4}{pred:<9}{exp:<9}{score:<7}{queue:<26}{team:<16}{r.get('subject','')[:50]} {mark}")

    if checkable:
        print("-" * 120)
        print(f"Accuracy: {correct}/{checkable} = {correct/checkable:.0%}")
        print("Note: rows 17/20 intentionally mix 'urgent'/'cannot login' with how-to wording")
        print("to show rule-based limits — tune keywords or move to Einstein/ML if needed.")


if __name__ == "__main__":
    main()