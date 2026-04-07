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
        const data = (await res.json().catch(() => (null))) as
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
    <div className="page">
      <span className="badge">Account</span>
      <h1>Email confirmation</h1>

      {phase === 'loading' && (
        <p className="lead">
          Confirming your email…
        </p>
      )}

      {phase !== 'loading' && (
        <>
          <div className={phase === 'ok' ? 'status ok' : 'status err'}>{message}</div>
          {phase === 'ok' && (
            <p style={{ marginTop: '1rem' }}>
              <Link to="/support" className="btn">
                Need help?
              </Link>
            </p>
          )}
          {(phase === 'err' || phase === 'missing') && (
            <p style={{ marginTop: '1rem' }} className="muted">
              You can request a new confirmation email from the MaillardMap app after signing up, or{' '}
              <Link to="/support">contact support</Link>.
            </p>
          )}
        </>
      )}
    </div>
  );
}
