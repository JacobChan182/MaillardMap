import { FormEvent, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { apiBase } from '../lib/apiBase';

type SubmitState = 'idle' | 'sending' | 'ok' | 'err';

export function ResetPasswordPage() {
  const [params] = useSearchParams();
  const token = useMemo(() => params.get('token')?.trim() ?? '', [params]);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [state, setState] = useState<SubmitState>('idle');
  const [message, setMessage] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!token) {
      setState('err');
      setMessage('This reset link is missing a token. Request a new one in the app.');
      return;
    }
    if (password.length < 8) {
      setState('err');
      setMessage('Password must be at least 8 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setState('err');
      setMessage("Passwords don't match.");
      return;
    }

    const base = apiBase();
    if (!base) {
      setState('err');
      setMessage('This site is not configured with an API URL. Please contact support.');
      return;
    }

    setState('sending');
    setMessage('');
    try {
      const res = await fetch(`${base}/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, password }),
      });
      const data = (await res.json().catch(() => null)) as
        | { ok?: boolean; message?: string; error?: { message?: string } }
        | null;
      if (res.ok && data?.ok) {
        setState('ok');
        setMessage(data.message ?? 'Password updated. You can now log in from the app.');
        setPassword('');
        setConfirmPassword('');
        return;
      }
      setState('err');
      setMessage(data?.error?.message ?? `Could not reset password (${res.status}).`);
    } catch {
      setState('err');
      setMessage('Could not reach the server. Check your connection and try again.');
    }
  }

  return (
    <main className="page page-narrow">
      <span className="badge">Account</span>
      <h1>Reset password</h1>
      <p className="lead">Set a new password for your MaillardMap account.</p>

      <div className="card">
        <form onSubmit={onSubmit}>
          <div className="form-field">
            <label htmlFor="password">New password</label>
            <input
              id="password"
              type="password"
              required
              minLength={8}
              maxLength={200}
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={state === 'sending' || state === 'ok'}
            />
          </div>
          <div className="form-field">
            <label htmlFor="confirmPassword">Confirm password</label>
            <input
              id="confirmPassword"
              type="password"
              required
              minLength={8}
              maxLength={200}
              autoComplete="new-password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              disabled={state === 'sending' || state === 'ok'}
            />
          </div>

          <button className="btn" type="submit" disabled={state === 'sending' || state === 'ok'}>
            {state === 'sending' ? 'Saving…' : 'Set new password'}
          </button>
        </form>

        {message && (
          <p className={state === 'ok' ? 'status ok' : 'status err'} style={{ marginTop: '1rem' }}>
            {message}
          </p>
        )}
        <p className="muted" style={{ marginTop: '1rem' }}>
          Return to the app and log in after resetting your password.
          {' '}
          <Link to="/support">Need help?</Link>
        </p>
      </div>
    </main>
  );
}
