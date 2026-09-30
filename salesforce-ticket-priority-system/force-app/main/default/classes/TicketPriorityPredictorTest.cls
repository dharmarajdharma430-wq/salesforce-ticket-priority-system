@IsTest
private class TicketPriorityPredictorTest {

    @IsTest static void testCriticalOutage() {
        TicketPriorityPredictor.Prediction p = TicketPriorityPredictor.predict(
            'Production outage — system down', 'All users unable to access, suspected outage', 'Platinum');
        System.assertEquals('Critical', p.priority, 'Outage + platinum should be Critical. Reason: ' + p.reason);
        System.assert(p.score >= 50, 'Score should be >= 50, got ' + p.score);
    }

    @IsTest static void testHighUrgent() {
        TicketPriorityPredictor.Prediction p = TicketPriorityPredictor.predict(
            'Urgent: payment failures', 'Customers report payment failed, need escalation', null);
        System.assertEquals('High', p.priority, 'Urgent billing issue should be High. Reason: ' + p.reason);
    }

    @IsTest static void testMediumError() {
        TicketPriorityPredictor.Prediction p = TicketPriorityPredictor.predict(
            'Dashboard slow', 'Reports show delay and occasional error', null);
        System.assertEquals('Medium', p.priority, 'Slow/error should be Medium. Reason: ' + p.reason);
    }

    @IsTest static void testLowQuestion() {
        TicketPriorityPredictor.Prediction p = TicketPriorityPredictor.predict(
            'Question on documentation', 'How to export reports? Training request', 'Bronze');
        System.assertEquals('Low', p.priority, 'How-to question should be Low. Reason: ' + p.reason);
    }

    @IsTest static void testAssignmentRouting() {
        TicketAssignmentService.Assignment c =
            TicketAssignmentService.assign('Critical', 'Outage', 'System down');
        System.assertEquals('Critical_Support_Queue', c.queueName);
        System.assertEquals(true, c.escalated);
        System.assertEquals(1, c.slaHours);

        TicketAssignmentService.Assignment low =
            TicketAssignmentService.assign('Low', 'Billing question', 'Invoice refund question');
        System.assertEquals('Billing_Team', low.team);
        System.assertEquals(72, low.slaHours);
    }

    @IsTest static void testTriggerHandlerBulk() {
        List<Case> cases = new List<Case>{
            new Case(Subject = 'Outage: production down', Description = 'System down for all users', Origin = 'Web'),
            new Case(Subject = 'How to export?', Description = 'Documentation question', Origin = 'Email')
        };
        CaseTriggerHandler.beforeInsert(cases);
        System.assertEquals('Critical', cases[0].Priority);
        System.assertEquals('Low', cases[1].Priority);
    }

    @IsTest static void testNullSafety() {
        TicketPriorityPredictor.Prediction p = TicketPriorityPredictor.predict(null, null, null);
        System.assertEquals('Low', p.priority);
        TicketAssignmentService.Assignment a = TicketAssignmentService.assign(null, null, null);
        System.assertNotEquals(null, a.queueName);
    }
}
