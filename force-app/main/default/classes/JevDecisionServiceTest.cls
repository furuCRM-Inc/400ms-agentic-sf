@isTest
private class JevDecisionServiceTest {

    // ── Mock: 200 CRITICAL response ────────────────────────────────────────────

    private class MockCritical implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod(), 'method');
            System.assert(req.getEndpoint().contains('/v1/systemone'), 'endpoint');
            System.assert(req.getHeader('Authorization').startsWith('Bearer '), 'auth header');

            Map<String, Object> reqBody = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('jev-latest', reqBody.get('model'), 'model');
            System.assertNotEquals(null, reqBody.get('state'),     'state present');
            System.assertNotEquals(null, reqBody.get('questions'), 'questions present');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'model' => 'jev-1.13.0',
                'answers' => new Map<String, Object>{
                    'is_critical' => new Map<String, Object>{
                        'type' => 'noul',
                        'noul' => 0.97
                    },
                    'recommended_action' => new Map<String, Object>{
                        'type'          => 'choice',
                        'choice'        => 'APPROVE_MAX_REFUND',
                        'confidence'    => 0.95,
                        'probabilities' => new Map<String, Double>{
                            'APPROVE_MAX_REFUND' => 0.95,
                            'PARTIAL_REFUND'     => 0.03,
                            'ESCALATE'           => 0.01,
                            'STANDARD_RESPONSE'  => 0.01
                        }
                    },
                    'urgency_level' => new Map<String, Object>{
                        'type'       => 'score',
                        'score'      => 2.85,
                        'confidence' => 0.92
                    }
                },
                'usage' => new Map<String, Integer>{
                    'input_tokens'  => 412,
                    'output_tokens' => 58
                }
            }));
            return res;
        }
    }

    // ── Mock: 200 STANDARD response ────────────────────────────────────────────

    private class MockStandard implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'model' => 'jev-1.13.0',
                'answers' => new Map<String, Object>{
                    'is_critical' => new Map<String, Object>{
                        'type' => 'noul', 'noul' => 0.12
                    },
                    'recommended_action' => new Map<String, Object>{
                        'type' => 'choice', 'choice' => 'STANDARD_RESPONSE', 'confidence' => 0.78,
                        'probabilities' => new Map<String, Double>{ 'STANDARD_RESPONSE' => 0.78 }
                    },
                    'urgency_level' => new Map<String, Object>{
                        'type' => 'score', 'score' => 0.4, 'confidence' => 0.81
                    }
                },
                'usage' => new Map<String, Integer>{ 'input_tokens' => 390, 'output_tokens' => 52 }
            }));
            return res;
        }
    }

    // ── Mock: 401 error ────────────────────────────────────────────────────────

    private class MockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error": "Invalid API key"}');
            return res;
        }
    }

    // ── Tests ──────────────────────────────────────────────────────────────────

    @isTest
    static void testEvaluate_critical() {
        Test.setMock(HttpCalloutMock.class, new MockCritical());

        Test.startTest();
        JevDecisionService.Decision d = JevDecisionService.evaluate(
            'System down. Lost $50,000. Cancel NOW!',
            'Enterprise', 0, 50000
        );
        Test.stopTest();

        System.assertEquals('CRITICAL',           d.urgency,            'urgency');
        System.assertEquals('APPROVE_MAX_REFUND',  d.recommendedAction,  'recommendedAction');
        System.assertEquals('TIER_3_RETENTION',    d.routeTo,            'routeTo');
        System.assert(d.confidence >= 0.9,  'confidence >= 0.9');
        System.assert(d.noulCritical >= 0.8, 'noulCritical >= 0.8');
        System.assert(d.urgencyScore >= 2.0, 'urgencyScore >= 2.0');
        System.assertEquals(412, d.inputTokens,  'inputTokens');
        System.assertEquals(58,  d.outputTokens, 'outputTokens — minimal, no text generated');
        System.assert(d.latencyMs >= 0, 'latencyMs recorded');
    }

    @isTest
    static void testEvaluate_standard() {
        Test.setMock(HttpCalloutMock.class, new MockStandard());

        Test.startTest();
        JevDecisionService.Decision d = JevDecisionService.evaluate(
            'How do I reset my password?',
            'Standard', 0, 0
        );
        Test.stopTest();

        System.assertEquals('STANDARD',          d.urgency,           'urgency');
        System.assertEquals('STANDARD_RESPONSE', d.recommendedAction, 'recommendedAction');
        System.assertEquals('STANDARD_QUEUE',    d.routeTo,           'routeTo');
        System.assert(d.noulCritical < 0.5, 'noulCritical low for standard message');
    }

    @isTest
    static void testEvaluate_apiError_throws() {
        Test.setMock(HttpCalloutMock.class, new MockError());

        Test.startTest();
        try {
            JevDecisionService.evaluate('test', 'Standard', 0, 0);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('401'), 'Error contains status code');
        }
        Test.stopTest();
    }

    @isTest
    static void testParseResponse_escalate() {
        String body = JSON.serialize(new Map<String, Object>{
            'model' => 'jev-1.13.0',
            'answers' => new Map<String, Object>{
                'is_critical' => new Map<String, Object>{ 'type' => 'noul', 'noul' => 0.60 },
                'recommended_action' => new Map<String, Object>{
                    'type' => 'choice', 'choice' => 'ESCALATE', 'confidence' => 0.70,
                    'probabilities' => new Map<String, Double>{ 'ESCALATE' => 0.70 }
                },
                'urgency_level' => new Map<String, Object>{
                    'type' => 'score', 'score' => 2.1, 'confidence' => 0.65
                }
            },
            'usage' => new Map<String, Integer>{ 'input_tokens' => 300, 'output_tokens' => 45 }
        });

        JevDecisionService.Decision d = JevDecisionService.parseResponse(body, 5000, 120);
        System.assertEquals('HIGH',           d.urgency,           'HIGH when score >= 2 but noul < 0.8');
        System.assertEquals('ESCALATE',       d.recommendedAction, 'recommendedAction');
        System.assertEquals('SENIOR_SUPPORT', d.routeTo,           'routeTo for ESCALATE');
    }
}
