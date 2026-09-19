/**
 * @description Calls TypeSafe AI's Jev — the System One model.
 *
 * Jev evaluates typed Questions against a State in one parallel pass.
 * It returns calibrated probabilities and decision values — no text generated,
 * no hallucination possible, no output token charges.
 *
 * Endpoint : POST https://api.typesafe.ai/v1/systemone
 * Model    : jev-latest
 * Latency  : 70–500ms (parallel multi-question evaluation)
 * Cost     : $0.042 / 1M input tokens · output tokens FREE
 * Docs     : https://docs.typesafe.ai/api
 *
 * Setup:
 *   1. Get API key at https://typesafe.ai
 *   2. Setup > Custom Labels > TypeSafe_API_Key > paste key
 *   3. Setup > Named Credentials > TypeSafe Jev > confirm endpoint
 */
public with sharing class JevDecisionService {

    private static final String ENDPOINT = 'callout:TypeSafe_Jev/v1/systemone';
    private static final String MODEL    = 'jev-latest';

    // ── Public result ──────────────────────────────────────────────────────────

    public class Decision {
        public String  urgency;             // CRITICAL | HIGH | STANDARD
        public String  recommendedAction;   // APPROVE_MAX_REFUND | PARTIAL_REFUND | ESCALATE | STANDARD_RESPONSE
        public String  routeTo;             // TIER_3_RETENTION | SENIOR_SUPPORT | STANDARD_QUEUE
        public Double  confidence;          // 0.0–1.0 from Jev choice confidence
        public Double  noulCritical;        // raw Jev noul probability 0.0–1.0
        public Double  urgencyScore;        // raw Jev score 0–3
        public Double  threatValue;
        public Long    latencyMs;
        public Integer inputTokens;
        public Integer outputTokens;
    }

    // ── Main entry point ───────────────────────────────────────────────────────

    public static Decision evaluate(
        String  message,
        String  customerTier,
        Integer openCaseCount,
        Decimal threatValueUsd
    ) {
        Long start = System.currentTimeMillis();

        // Build state — can be plain text or JSON string
        String stateJson = JSON.serialize(new Map<String, Object>{
            'message'          => message,
            'customer_tier'    => customerTier,
            'open_case_count'  => openCaseCount,
            'threat_value_usd' => threatValueUsd
        });

        // Build questions — three Jev primitives in one request
        Map<String, Object> questions = new Map<String, Object>{

            // Noul: returns probability 0.0–1.0 (not boolean — calibrated)
            'is_critical' => new Map<String, Object>{
                'type'         => 'noul',
                'instructions' => 'Does this message indicate a critical business emergency '
                                + 'requiring immediate VIP retention intervention and maximum refund authorization?'
            },

            // Choice: returns the winning option + confidence + all probabilities
            'recommended_action' => new Map<String, Object>{
                'type'         => 'choice',
                'instructions' => 'Select the most appropriate retention action for this customer situation.',
                'criteria'     => new Map<String, String>{
                    'APPROVE_MAX_REFUND' => 'Approve full refund immediately for high-value VIP retention',
                    'PARTIAL_REFUND'     => 'Offer partial refund and service credit as compromise',
                    'ESCALATE'           => 'Escalate to senior support team without immediate refund decision',
                    'STANDARD_RESPONSE'  => 'Route to standard support queue — low risk, no urgent action needed'
                }
            },

            // Score: returns weighted score across ordered levels
            'urgency_level' => new Map<String, Object>{
                'type'         => 'score',
                'instructions' => 'Rate the urgency of this customer situation.',
                'levels'       => new Map<String, String>{
                    '0' => 'Low: No immediate churn risk, standard response acceptable',
                    '1' => 'Medium: Risk of dissatisfaction, same-day response recommended',
                    '2' => 'High: Significant churn risk, priority response within the hour',
                    '3' => 'Critical: High-value customer threatening cancellation and public escalation'
                }
            }
        };

        Map<String, Object> body = new Map<String, Object>{
            'model'     => MODEL,
            'state'     => stateJson,
            'questions' => questions
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + System.Label.TypeSafe_API_Key);
        req.setBody(JSON.serialize(body));
        req.setTimeout(5000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Jev API error ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        Long latencyMs = System.currentTimeMillis() - start;
        return parseResponse(res.getBody(), threatValueUsd, latencyMs);
    }

    // ── Response parser ────────────────────────────────────────────────────────

    @TestVisible
    static Decision parseResponse(String body, Decimal threatValue, Long latencyMs) {
        Map<String, Object> parsed  = (Map<String, Object>) JSON.deserializeUntyped(body);
        Map<String, Object> answers = (Map<String, Object>) parsed.get('answers');
        Map<String, Object> usage   = (Map<String, Object>) parsed.get('usage');

        // is_critical — Noul returns probability 0.0–1.0
        Map<String, Object> criticalAnswer = (Map<String, Object>) answers.get('is_critical');
        Double noulProb = (Double) criticalAnswer.get('noul');

        // recommended_action — Choice returns winning option + confidence
        Map<String, Object> actionAnswer = (Map<String, Object>) answers.get('recommended_action');
        String action     = (String) actionAnswer.get('choice');
        Double confidence = (Double) actionAnswer.get('confidence');

        // urgency_level — Score returns weighted score across levels
        Map<String, Object> urgencyAnswer = (Map<String, Object>) answers.get('urgency_level');
        Double score = urgencyAnswer.get('score') instanceof Double
            ? (Double) urgencyAnswer.get('score')
            : Double.valueOf(String.valueOf(urgencyAnswer.get('score')));

        Decision d          = new Decision();
        d.noulCritical      = noulProb;
        d.urgencyScore      = score;
        d.urgency           = noulProb >= 0.80 ? 'CRITICAL'
                            : score    >= 2.0  ? 'HIGH'
                            :                    'STANDARD';
        d.recommendedAction = action;
        d.routeTo           = action == 'APPROVE_MAX_REFUND' ? 'TIER_3_RETENTION'
                            : action == 'ESCALATE'           ? 'SENIOR_SUPPORT'
                            :                                  'STANDARD_QUEUE';
        d.confidence        = confidence;
        d.threatValue       = threatValue;
        d.latencyMs         = latencyMs;
        d.inputTokens       = usage != null ? (Integer) usage.get('input_tokens')  : null;
        d.outputTokens      = usage != null ? (Integer) usage.get('output_tokens') : null;

        return d;
    }
}
