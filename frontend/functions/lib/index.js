"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.api = void 0;
const cors_1 = __importDefault(require("cors"));
const express_1 = __importDefault(require("express"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const resend_1 = require("resend");
const zod_1 = require("zod");
const resendApiKey = (0, params_1.defineSecret)('RESEND_API_KEY');
const supportInbox = (0, params_1.defineString)('SUPPORT_INBOX_EMAIL', { default: '' });
const resendFrom = (0, params_1.defineString)('RESEND_FROM_EMAIL', { default: '' });
const contactSchema = zod_1.z.object({
    name: zod_1.z.string().trim().min(1).max(120),
    email: zod_1.z.string().trim().email().max(254),
    subject: zod_1.z.string().trim().min(1).max(200),
    message: zod_1.z.string().trim().min(1).max(8000),
    website: zod_1.z.string().optional(),
});
function buildApp() {
    const app = (0, express_1.default)();
    app.use((0, cors_1.default)({ origin: true }));
    app.use(express_1.default.json({ limit: '64kb' }));
    app.get(['/health', '/api/health'], (_req, res) => {
        res.status(200).json({ ok: true, service: 'maillardmap-site-api' });
    });
    app.post(['/contact', '/api/contact'], async (req, res) => {
        if (req.body && typeof req.body.website === 'string' && req.body.website.length > 0) {
            return res.status(204).end();
        }
        const parsed = contactSchema.safeParse(req.body);
        if (!parsed.success) {
            const msg = parsed.error.errors.map((e) => e.message).join('; ');
            return res.status(400).json({
                ok: false,
                error: { code: 'VALIDATION_ERROR', message: msg || 'Invalid input' },
            });
        }
        const { name, email, subject, message } = parsed.data;
        const to = supportInbox.value().trim();
        const fromEmail = resendFrom.value().trim();
        if (!to || !fromEmail) {
            console.error('[contact] SUPPORT_INBOX_EMAIL or RESEND_FROM_EMAIL not configured');
            return res.status(503).json({
                ok: false,
                error: {
                    code: 'NOT_CONFIGURED',
                    message: 'Support email is not configured on the server.',
                },
            });
        }
        const apiKey = process.env.RESEND_API_KEY;
        if (!apiKey) {
            console.error('[contact] RESEND_API_KEY missing');
            return res.status(503).json({
                ok: false,
                error: { code: 'NOT_CONFIGURED', message: 'Email provider is not configured.' },
            });
        }
        try {
            const resend = new resend_1.Resend(apiKey);
            const { error } = await resend.emails.send({
                from: `MaillardMap Support <${fromEmail}>`,
                to: [to],
                replyTo: email,
                subject: `[MaillardMap] ${subject}`,
                html: `
          <p><strong>From:</strong> ${escapeHtml(name)} &lt;${escapeHtml(email)}&gt;</p>
          <p><strong>Subject:</strong> ${escapeHtml(subject)}</p>
          <hr />
          <pre style="white-space:pre-wrap;font-family:system-ui,sans-serif">${escapeHtml(message)}</pre>
        `,
            });
            if (error) {
                console.error('[contact] Resend error', error);
                return res.status(502).json({
                    ok: false,
                    error: { code: 'EMAIL_FAILED', message: 'Could not send message. Try again later.' },
                });
            }
            return res.status(200).json({ ok: true });
        }
        catch (e) {
            console.error('[contact]', e);
            return res.status(500).json({
                ok: false,
                error: { code: 'INTERNAL', message: 'Unexpected error sending message.' },
            });
        }
    });
    return app;
}
function escapeHtml(s) {
    return s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}
const expressApp = buildApp();
exports.api = (0, https_1.onRequest)({
    region: 'us-central1',
    secrets: [resendApiKey],
    invoker: 'public',
    memory: '256MiB',
    timeoutSeconds: 30,
}, (req, res) => expressApp(req, res));
