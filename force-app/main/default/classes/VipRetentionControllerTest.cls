@isTest
private class VipRetentionControllerTest {

    @isTest
    static void testProcessJevDecision() {
        Test.startTest();
        Map<String, Object> result = VipRetentionController.processJevDecision(
            'System down. Lost $50k. Cancel NOW!'
        );
        Test.stopTest();

        System.assertEquals('CRITICAL',           result.get('urgency'),             'urgency');
        System.assertEquals('APPROVE_MAX_REFUND', result.get('recommended_action'),  'recommended_action');
        System.assertEquals('TIER_3_RETENTION',   result.get('route_to'),            'route_to');
        System.assertNotEquals(null, result.get('confidence'),    'confidence present');
        System.assertNotEquals(null, result.get('latency_ms'),    'latency_ms present');
    }

    @isTest
    static void testApproveRefund() {
        Test.startTest();
        Map<String, Object> result = VipRetentionController.approveRefund(50000, 'VIP-001');
        Test.stopTest();

        System.assertEquals(true,   result.get('success'),      'success');
        System.assertEquals(50000,  result.get('refundAmount'),  'refundAmount');
        System.assertEquals('USD',  result.get('currency'),      'currency');
        System.assertNotEquals(null, result.get('transactionId'), 'transactionId present');
    }

    @isTest
    static void testRouteToVipRetention() {
        Test.startTest();
        Map<String, Object> result = VipRetentionController.routeToVipRetention('VIP-001');
        Test.stopTest();

        System.assertEquals(true,               result.get('success'),    'success');
        System.assertEquals('VIP Retention Team', result.get('assignedTo'), 'assignedTo');
        System.assertEquals(15,                 result.get('slaMinutes'), 'slaMinutes');
    }

    @isTest
    static void testGenerateReassuranceMessage_namedCustomer() {
        Test.startTest();
        String msg = VipRetentionController.generateReassuranceMessage('Tanaka-san');
        Test.stopTest();

        System.assert(msg.contains('Tanaka-san'), 'Contains customer name');
        System.assert(msg.contains('$50,000'),    'Contains refund amount');
        System.assert(msg.contains('REF-'),       'Contains transaction ref');
    }

    @isTest
    static void testGenerateReassuranceMessage_blankName() {
        Test.startTest();
        String msg = VipRetentionController.generateReassuranceMessage('');
        Test.stopTest();

        System.assert(msg.contains('Valued Customer'), 'Uses fallback name');
    }
}
