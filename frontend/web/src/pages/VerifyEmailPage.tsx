import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { apiBase } from '../lib/apiBase';

type Phase = 'loading' | 'ok' | 'err' | 'missing';

export function VerifyEmailPage() {
  const [params] = useSearchParams();
  const token = useMemo(() => params.get('token')?.trim() ?? '', [params]);
  const [phase, setPhase] = useState<Phase>('loading');
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!token) {
      setPhase('missing');
      setMessage('This link is missing a token. Open the confirmation link from your email.');
      return;
    }

    const base = apiBase();
    if (!base) {
      setPhase('err');
      setMessage('This site is not configured with an API URL. Please contact support.');
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const url = `${base}/auth/verify-email?token=${encodeURIComponent(token)}`;
        const res = await fetch(url);
        const data = (await res.json().catch(() => null)) as
          | { ok?: boolean; message?: string; error?: { message?: string } }
          | null;
        if (cancelled) return;
        if (res.ok && data && 'ok' in data && data.ok) {
          setPhase('ok');
          setMessage('Your email is confirmed. You can open MaillardMap and log in.');
          return;
        }
        const errText =
          data && typeof data === 'object' && data.error && typeof data.error.message === 'string'
            ? data.error.message
            : `Could not confirm email (${res.status}).`;
        setPhase('err');
        setMessage(errText);
      } catch {
        if (cancelled) return;
        setPhase('err');
        setMessage('Could not reach the server. Check your connection and try again.');
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [token]);

  return (
    <main className="page page-narrow">
      <span className="badge">Account</span>
      <h1>Email confirmation</h1>
      <p className="lead" style={phase === 'loading' ? undefined : { marginBottom: 0 }}>
        {phase === 'loading' ? 'Hang tight — we’re confirming your link.' : 'Here’s what we found.'}
      </p>

      {phase === 'loading' && (
        <div className="verify-card">
          <div className="verify-loading">
            <span className="spinner" aria-hidden />
            <span>Confirming with our servers…</span>
          </div>
        </div>
      )}

      {phase !== 'loading' && (
        <div className="verify-card">
          <div
            className={phase === 'ok' ? 'status ok' : 'status err'}
            style={{ marginTop: 0 }}
            role={phase === 'ok' ? 'status' : 'alert'}
          >
            {message}
          </div>
          {phase === 'ok' && (
            <div style={{ marginTop: '1.35rem' }}>
              <Link to="/support" className="btn">
                Need help?
              </Link>
            </div>
          )}
          {(phase === 'err' || phase === 'missing') && (
            <p style={{ marginTop: '1.25rem', marginBottom: 0 }} className="muted">
              Request a new confirmation email from the MaillardMap app, or{' '}
              <Link to="/support">contact support</Link>.
            </p>
          )}
        </div>
      )}
    </main>
  );
}
