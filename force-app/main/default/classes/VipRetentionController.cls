/**
 * @description Backend actions for the 400ms Agentic Salesforce demo.
 * Exposed to WebMCP-registered LWC tools and callable from Agentforce Actions.
 *
 * In production wire these to real Case / Order objects.
 * For demo, all methods return self-contained payloads with no DML.
 */
public with sharing class VipRetentionController {

    /**
     * Simulates Jev System 1 decision engine output.
     * In production replace with a real Jev API callout.
     */
    @AuraEnabled
    public static Map<String, Object> processJevDecision(String chatMessage) {
        Long latencyStart = System.currentTimeMillis();

        Map<String, Object> decision = new Map<String, Object>{
            'urgency'              => 'CRITICAL',
            'recommended_action'  => 'APPROVE_MAX_REFUND',
            'route_to'            => 'TIER_3_RETENTION',
            'confidence'          => 0.97,
            'threat_value'        => 50000,
            'sentiment_score'     => -0.94
        };

        decision.put('latency_ms', System.currentTimeMillis() - latencyStart);
        return decision;
    }

    /**
     * Approves a VIP retention refund.
     * In production: updates Case.Status, inserts Order Adjustment record.
     */
    @AuraEnabled
    public static Map<String, Object> approveRefund(Decimal amount, String caseId) {
        String txnId = 'REF-' + String.valueOf(System.currentTimeMillis()).right(8);

        return new Map<String, Object>{
            'success'       => true,
            'refundAmount'  => amount,
            'currency'      => 'USD',
            'transactionId' => txnId,
            'caseId'        => caseId,
            'processedAt'   => String.valueOf(DateTime.now())
        };
    }

    /**
     * Routes a case to the VIP Retention team.
     * In production: updates Case.OwnerId to VIP Retention Queue, sets Priority = Critical.
     */
    @AuraEnabled
    public static Map<String, Object> routeToVipRetention(String caseId) {
        return new Map<String, Object>{
            'success'    => true,
            'assignedTo' => 'VIP Retention Team',
            'priority'   => 'Critical',
            'slaMinutes' => 15,
            'caseId'     => caseId
        };
    }

    /**
     * Generates a personalised customer reassurance message.
     */
    @AuraEnabled
    public static String generateReassuranceMessage(String customerName) {
        String name = String.isBlank(customerName) ? 'Valued Customer' : customerName;
        String txnId = 'REF-' + String.valueOf(System.currentTimeMillis()).right(8);

        return 'Dear ' + name + ' — We sincerely apologise for the disruption. '
            + 'Your full refund of $50,000 has been authorised and will appear within 24 hours '
            + '(Reference: ' + txnId + '). '
            + 'Our VIP Retention Team will contact you personally within 15 minutes.';
    }
}
