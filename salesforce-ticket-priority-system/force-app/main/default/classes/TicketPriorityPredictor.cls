/**
 * TicketPriorityPredictor
 * Rule-based priority prediction for Case (Subject + Description + Account Tier).
 * No ML / Einstein dependency — deterministic, testable, deployable to any org.
 *
 * Score model (mirrored in scripts/simulate.py — keep in sync):
 *   Critical keywords (+30): outage, down, data loss, breach, security, production down, sla breach
 *   High keywords     (+15): urgent, critical, escalat, unable to work, payment fail
 *   Medium keywords   (+5):  slow, error, issue, delay, bug, broken
 *   Low indicators    (-10): question, how to, feature request, documentation, training
 *   Account tier bonus: Platinum +20, Gold +10, Silver +5, Bronze/Other 0
 *
 * Thresholds: >=50 Critical, >=30 High, >=10 Medium, else Low
 */
public with sharing class TicketPriorityPredictor {

    public class Prediction {
        public String priority;
        public Integer score;
        public String reason;
        public Prediction(String priority, Integer score, String reason) {
            this.priority = priority;
            this.score = score;
            this.reason = reason;
        }
    }

    private static final List<String> CRITICAL_KEYWORDS = new List<String>{
        'outage', 'down', 'data loss', 'breach', 'security',
        'production down', 'sla breach', 'system down'
    };
    private static final List<String> HIGH_KEYWORDS = new List<String>{
        'urgent', 'critical', 'escalat', 'unable to work', 'payment fail',
        'cannot access', 'blocked'
    };
    private static final List<String> MEDIUM_KEYWORDS = new List<String>{
        'slow', 'error', 'issue', 'delay', 'bug', 'broken', 'failing'
    };
    private static final List<String> LOW_KEYWORDS = new List<String>{
        'question', 'how to', 'feature request', 'documentation', 'training', 'suggestion'
    };

    public static Prediction predict(String subject, String description, String accountTier) {
        String text = ((subject == null ? '' : subject) + ' ' + (description == null ? '' : description)).toLowerCase();
        Integer score = 0;
        List<String> hits = new List<String>();

        for (String kw : CRITICAL_KEYWORDS) {
            if (text.contains(kw)) { score += 30; hits.add('CRITICAL:' + kw); }
        }
        for (String kw : HIGH_KEYWORDS) {
            if (text.contains(kw)) { score += 15; hits.add('HIGH:' + kw); }
        }
        for (String kw : MEDIUM_KEYWORDS) {
            if (text.contains(kw)) { score += 5; hits.add('MED:' + kw); }
        }
        for (String kw : LOW_KEYWORDS) {
            if (text.contains(kw)) { score -= 10; hits.add('LOW:' + kw); }
        }

        String tier = (accountTier == null ? '' : accountTier.toLowerCase());
        if (tier == 'platinum') { score += 20; hits.add('TIER:platinum+20'); }
        else if (tier == 'gold') { score += 10; hits.add('TIER:gold+10'); }
        else if (tier == 'silver') { score += 5; hits.add('TIER:silver+5'); }

        String priority;
        if (score >= 50) priority = 'Critical';
        else if (score >= 30) priority = 'High';
        else if (score >= 10) priority = 'Medium';
        else priority = 'Low';

        String reason = 'score=' + score + ' | ' + String.join(hits, ', ');
        if (hits.isEmpty()) reason = 'score=0 | no keyword/tier match, defaulted to Low';
        return new Prediction(priority, score, reason);
    }

    // Convenience overload for Case records
    public static Prediction predictForCase(String subject, String description) {
        return predict(subject, description, null);
    }
}
