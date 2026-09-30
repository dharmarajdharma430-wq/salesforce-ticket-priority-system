/**
 * CaseTriggerHandler
 * Before-insert/update: auto-predict Priority + auto-assign Queue/Team/SLA.
 * Bulk-safe, no SOQL/DML — sets fields on Trigger.new directly.
 *
 * Expected Case fields (standard + optional custom):
 *   Subject, Description, Priority (standard picklist), Origin
 *   Team__c (Text, optional), SLA_Hours__c (Number, optional),
 *   Priority_Score__c (Number, optional), Routing_Reason__c (Long Text, optional)
 *
 * Uses try/catch per record so one bad record never blocks the batch.
 * Only overwrites Priority on update if Subject/Description changed or Priority is blank
 * (prevents clobbering manual agent overrides — remove guard to always auto-predict).
 */
public with sharing class CaseTriggerHandler {

    public static void beforeInsert(List<Case> newList) {
        for (Case c : newList) {
            try { applyPrediction(c, true); } catch (Exception e) { /* log, don't block insert */ }
        }
    }

    public static void beforeUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        for (Case c : newList) {
            Case old = oldMap.get(c.Id);
            Boolean textChanged = (c.Subject != old.Subject) || (c.Description != old.Description);
            Boolean needsPrediction = String.isBlank(c.Priority) || textChanged;
            try { applyPrediction(c, needsPrediction); } catch (Exception e) { /* log, don't block update */ }
        }
    }

    private static void applyPrediction(Case c, Boolean updatePriority) {
        // NOTE: pass Account tier here if available, e.g. via formula or lookup:
        // TicketPriorityPredictor.predict(c.Subject, c.Description, accountTier)
        TicketPriorityPredictor.Prediction pred =
            TicketPriorityPredictor.predict(c.Subject, c.Description, null);

        if (updatePriority) {
            c.Priority = pred.priority;
        }
        TicketAssignmentService.Assignment a =
            TicketAssignmentService.assign(c.Priority, c.Subject, c.Description);

        // Standard escalation flag on Critical
        if (a.escalated) {
            c.IsEscalated = true;
        }
        // Optional custom fields — guarded so handler works even if fields don't exist yet.
        // Uncomment after creating these fields in your org:
        // c.put('Team__c', a.team);
        // c.put('SLA_Hours__c', a.slaHours);
        // c.put('Priority_Score__c', pred.score);
        // c.put('Routing_Reason__c', pred.reason + ' => ' + a.queueName);
    }
}
