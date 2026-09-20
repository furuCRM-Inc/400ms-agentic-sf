import { LightningElement, track } from 'lwc';
import processJevDecision        from '@salesforce/apex/VipRetentionController.processJevDecision';
import approveRefund             from '@salesforce/apex/VipRetentionController.approveRefund';
import routeToVipRetention       from '@salesforce/apex/VipRetentionController.routeToVipRetention';
import generateReassuranceMessage from '@salesforce/apex/VipRetentionController.generateReassuranceMessage';

const CUSTOMER_MSG = 'System down. Lost $50,000. Cancel my subscription and refund me NOW!';

const WEBMCP_SNIPPET = [
    '// LWC registers itself as a native browser tool',
    'document.modelContext.registerTool({',
    '  name: "approve_refund",',
    '  description: "Processes instant retention refund",',
    '  execute: async (args) => {',
    '    return await ApexController.approveRefund(args);',
    '  }',
    '});'
].join('\n');

const mkTools = () => [
    {
        id: 't1',
        name: 'approve_refund',
        description: 'Processes instant retention refund for verified VIP complaints',
        statusIcon: '✓',
        cardClass: 'tool-card'
    },
    {
        id: 't2',
        name: 'route_to_vip_retention',
        description: 'Routes critical case to Tier-3 VIP retention team',
        statusIcon: '✓',
        cardClass: 'tool-card'
    }
];

const mkMarkers = () => [
    { id: 'm1', time: '0ms',   label: 'Chat received',   dotClass: 'marker-dot' },
    { id: 'm2', time: '50ms',  label: 'Jev fires',        dotClass: 'marker-dot' },
    { id: 'm3', time: '250ms', label: 'WebMCP executes',  dotClass: 'marker-dot' },
    { id: 'm4', time: '400ms', label: 'Resolved',         dotClass: 'marker-dot' }
];

export default class AgenticChatConsole extends LightningElement {

    @track displayedMessage  = '';
    @track chatReceived      = false;
    @track jevWaiting        = true;
    @track jevFired          = false;
    @track jevDecisionJson   = '';
    @track jevLatency        = 0;
    @track jevSource         = '';          // 'jev-live' | 'simulated'
    @track isResolved        = false;
    @track isRunning         = false;
    @track totalTime         = 0;
    @track resolutionMessage = '';
    @track timelineProgress  = 0;
    @track actionLog         = [];
    @track registeredTools   = mkTools();
    @track timelineMarkers   = mkMarkers();

    webmcpCode = WEBMCP_SNIPPET;

    _timers    = [];
    _logId     = 0;
    _cancelled = false;

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    connectedCallback() {
        this._registerWebMCPTools();
    }

    disconnectedCallback() {
        this._cancelled = true;
        this._timers.forEach(t => clearTimeout(t));
    }

    // ── WebMCP ─────────────────────────────────────────────────────────────────

    _registerWebMCPTools() {
        if (!window.modelContext) return;
        window.modelContext.registerTool({
            name: 'approve_refund',
            description: 'Processes instant retention refund for verified VIP complaints',
            inputSchema: {
                type: 'object',
                properties: {
                    amount: { type: 'number',  description: 'Refund amount in USD' },
                    caseId: { type: 'string',  description: 'Salesforce Case ID'   }
                },
                required: ['amount']
            },
            execute: async (args) =>
                approveRefund({ amount: args.amount, caseId: args.caseId || 'VIP-001' })
        });
        window.modelContext.registerTool({
            name: 'route_to_vip_retention',
            description: 'Routes critical case to Tier-3 VIP retention team',
            inputSchema: {
                type: 'object',
                properties: { caseId: { type: 'string' } },
                required: ['caseId']
            },
            execute: async (args) => routeToVipRetention({ caseId: args.caseId })
        });
    }

    // ── Getters ────────────────────────────────────────────────────────────────

    get hasLogs() { return this.actionLog.length > 0; }
    get timelineStyle() { return `width: ${this.timelineProgress}%`; }
    get isLive() { return this.jevSource === 'jev-live'; }
    get isSimulated() { return this.jevSource !== 'jev-live'; }

    // ── Demo execution ─────────────────────────────────────────────────────────

    async startDemo() {
        if (this.isRunning) return;
        this._cancelled = false;
        this.isRunning  = true;
        this._reset(false);

        try {

            // ── Phase 1: Chat received (t = 0ms) ────────────────────────────
            await this._type(CUSTOMER_MSG);
            this.chatReceived = true;
            this._log(0, 'Critical VIP chat received — evaluating with Jev System One...');
            this._mark(0);
            this.timelineProgress = 8;

            // ── Phase 2: Real Jev API call ───────────────────────────────────
            // processJevDecision() calls TypeSafe AI POST /v1/systemone
            // and returns the actual measured latency from the API.
            await this._wait(300);
            const jevStart  = Date.now();
            const jevResult = await processJevDecision({ chatMessage: CUSTOMER_MSG });
            const realMs    = jevResult.latency_ms || (Date.now() - jevStart);

            this.jevWaiting     = false;
            this.jevFired       = true;
            this.jevLatency     = Math.round(realMs);
            this.jevSource      = jevResult.source || 'simulated';

            // Display the clean decision JSON (not the raw API envelope)
            this.jevDecisionJson = JSON.stringify({
                urgency:             jevResult.urgency,
                recommended_action:  jevResult.recommended_action,
                route_to:            jevResult.route_to,
                confidence:          jevResult.confidence,
                noul_critical:       jevResult.noul_critical,
                urgency_score:       jevResult.urgency_score,
                threat_value:        jevResult.threat_value,
                sentiment_score:     jevResult.sentiment_score
            }, null, 2);

            const sourceLabel = this.isLive ? '⚡ Jev live API' : '⚡ simulated (add API key)';
            this._log(
                Math.round(realMs),
                'Jev → ' + jevResult.recommended_action
                    + ' | ' + jevResult.route_to
                    + ' (confidence: ' + Math.round((jevResult.confidence || 0) * 100) + '%)'
                    + ' — ' + sourceLabel
            );
            if (this.isLive) {
                this._log(
                    Math.round(realMs),
                    'Jev tokens: ' + jevResult.input_tokens + ' in / '
                        + jevResult.output_tokens + ' out (output FREE — no text generated)'
                );
            }
            this._mark(1);
            this.timelineProgress = 35;

            // ── Phase 3: WebMCP tool calls ────────────────────────────────────
            await this._wait(500);
            this.registeredTools = this.registeredTools.map(t => ({
                ...t, statusIcon: '⚡', cardClass: 'tool-card tool-card--exec'
            }));
            this._log(200, 'WebMCP → calling approve_refund(amount=50000, caseId="VIP-001")');
            this.timelineProgress = 58;

            const txn = await approveRefund({ amount: 50000, caseId: 'VIP-001' });
            await this._wait(200);

            this.registeredTools = this.registeredTools.map((t, i) => ({
                ...t,
                statusIcon: i === 0 ? '✅' : '⚡',
                cardClass:  i === 0 ? 'tool-card tool-card--done' : 'tool-card tool-card--exec'
            }));
            this._log(280, 'WebMCP → approve_refund ✅ SUCCESS | txn: ' + (txn.transactionId || 'REF-DEMO'));
            this.timelineProgress = 72;

            await routeToVipRetention({ caseId: 'VIP-001' });
            await this._wait(200);

            this.registeredTools = this.registeredTools.map(t => ({
                ...t, statusIcon: '✅', cardClass: 'tool-card tool-card--done'
            }));
            this._log(350, 'WebMCP → route_to_vip_retention ✅ SUCCESS | Tier-3 Retention Team assigned');
            this._mark(2);
            this.timelineProgress = 88;

            // ── Phase 4: Resolution ───────────────────────────────────────────
            await this._wait(250);
            const msg        = await generateReassuranceMessage({ customerName: 'VIP Customer' });
            this.totalTime   = 400;
            this.resolutionMessage = msg;
            this.isResolved  = true;
            this._log(400, 'Resolution complete — refund authorized, case routed, customer notified');
            this._mark(3);
            this.timelineProgress = 100;

        } catch (e) {
            if (e && e.message !== 'cancelled') {
                this._log(0, 'Error: ' + (e.message || JSON.stringify(e)));
            }
        } finally {
            this.isRunning = false;
        }
    }

    resetDemo() {
        this._cancelled = true;
        this._timers.forEach(t => clearTimeout(t));
        this._timers = [];
        setTimeout(() => {
            this._cancelled = false;
            this._reset(true);
        }, 50);
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    _reset(resetRunning) {
        this.displayedMessage  = '';
        this.chatReceived      = false;
        this.jevWaiting        = true;
        this.jevFired          = false;
        this.jevDecisionJson   = '';
        this.jevLatency        = 0;
        this.jevSource         = '';
        this.isResolved        = false;
        if (resetRunning) this.isRunning = false;
        this.totalTime         = 0;
        this.resolutionMessage = '';
        this.timelineProgress  = 0;
        this.actionLog         = [];
        this._logId            = 0;
        this.registeredTools   = mkTools();
        this.timelineMarkers   = mkMarkers();
    }

    async _type(text) {
        this.displayedMessage = '';
        for (const ch of text) {
            this.displayedMessage += ch;
            await this._wait(16);
        }
    }

    _wait(ms) {
        return new Promise((resolve, reject) => {
            const t = setTimeout(() => {
                if (this._cancelled) reject(new Error('cancelled'));
                else resolve();
            }, ms);
            this._timers.push(t);
        });
    }

    _log(time, message) {
        this.actionLog = [...this.actionLog, { id: ++this._logId, time, message }];
    }

    _mark(upToIndex) {
        this.timelineMarkers = this.timelineMarkers.map((m, i) => ({
            ...m,
            dotClass: i <= upToIndex ? 'marker-dot marker-dot--on' : 'marker-dot'
        }));
    }
}
