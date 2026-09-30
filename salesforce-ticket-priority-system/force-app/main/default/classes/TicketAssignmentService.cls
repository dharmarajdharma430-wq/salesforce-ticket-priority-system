/**
 * TicketAssignmentService
 * Maps predicted Priority + subject keywords to Queue / Team + SLA.
 * Bulk-safe: operates on Lists, no SOQL/DML inside loops.
 *
 * Routing table:
 *   Critical -> Queue: Critical_Support_Queue, SLA 1h,  escalated=true
 *   High     -> Queue: Senior_Support_Queue,   SLA 4h
 *   Medium   -> Queue: General_Support_Queue,  SLA 24h
 *   Low      -> Queue: Junior_Support_Queue,   SLA 72h
 *
 * Skill override (subject/description contains):
 *   billing/invoice/refund/payment -> Billing_Team
 *   security/breach/login/access   -> Security_Team
 *   outage/api/integration/error   -> Technical_Team
 * Skill is appended as Team__c suggestion; Queue stays priority-driven
 * unless priority is Low (skill queue wins for faster resolution).
 *
 * NOTE: Replace QUEUE_DEVELOPER_NAMES with real Group DeveloperNames in your org,
 * or swap to Custom Metadata (Ticket_Routing__mdt) for admin-editable routing.
 */
public with sharing class TicketAssignmentService {

    public class Assignment {
        public String queueName;
        public String team;
        public Integer slaHours;
        public Boolean escalated;
        public Assignment(String queueName, String team, Integer slaHours, Boolean escalated) {
            this.queueName = queueName;
            this.team = team;
            this.slaHours = slaHours;
            this.escalated = escalated;
        }
    }

    public static Assignment assign(String priority, String subject, String description) {
        String text = ((subject == null ? '' : subject) + ' ' + (description == null ? '' : description)).toLowerCase();

        // Skill detection
        String team = 'General';
        if (text.contains('billing') || text.contains('invoice') || text.contains('refund') || text.contains('payment')) {
            team = 'Billing_Team';
        } else if (text.contains('security') || text.contains('breach') || text.contains('login') || text.contains('access')) {
            team = 'Security_Team';
        } else if (text.contains('outage') || text.contains('api') || text.contains('integration') || text.contains('error') || text.contains('down')) {
            team = 'Technical_Team';
        }

        String p = (priority == null ? 'Low' : priority);
        if (p == 'Critical') {
            return new Assignment('Critical_Support_Queue', team, 1, true);
        } else if (p == 'High') {
            return new Assignment('Senior_Support_Queue', team, 4, false);
        } else if (p == 'Medium') {
            return new Assignment('General_Support_Queue', team, 24, false);
        } else {
            // Low priority: route to skill queue directly when a skill matched
            String q = (team != 'General') ? team + '_Queue' : 'Junior_Support_Queue';
            return new Assignment(q, team, 72, false);
        }
    }
}
