import { FormEvent, useState } from 'react';
import { apiBase } from '../lib/apiBase';

type SubmitState = 'idle' | 'sending' | 'ok' | 'err';

export function SupportPage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [website, setWebsite] = useState('');
  const [state, setState] = useState<SubmitState>('idle');
  const [errMsg, setErrMsg] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setState('sending');
    setErrMsg('');
    const base = apiBase();
    if (!base) {
      setErrMsg('This site is missing API configuration. Contact us by email from the privacy policy.');
      setState('err');
      return;
    }
    try {
      const res = await fetch(`${base}/support/contact`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, subject, message, website }),
      });
      if (res.status === 204) {
        setState('ok');
        return;
      }
      const data = (await res.json().catch(() => ({}))) as { ok?: boolean; error?: { message?: string } };
      if (!res.ok) {
        setErrMsg(data.error?.message ?? `Request failed (${res.status})`);
        setState('err');
        return;
      }
      setState('ok');
      setName('');
      setEmail('');
      setSubject('');
      setMessage('');
      setWebsite('');
    } catch {
      setErrMsg('Network error. Try again or email us directly.');
      setState('err');
    }
  }

  return (
    <div className="page">
      <span className="badge">Support</span>
      <h1>Contact us</h1>
      <p className="lead">Questions, bugs, or feedback — we read every message.</p>

      <div className="card">
        <form onSubmit={onSubmit}>
          <div className="form-field hp" aria-hidden="true">
            <label htmlFor="website">Website</label>
            <input
              id="website"
              name="website"
              tabIndex={-1}
              autoComplete="off"
              value={website}
              onChange={(e) => setWebsite(e.target.value)}
            />
          </div>
          <div className="form-field">
            <label htmlFor="name">Name</label>
            <input
              id="name"
              name="name"
              required
              maxLength={120}
              autoComplete="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
          <div className="form-field">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              name="email"
              type="email"
              required
              maxLength={254}
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="form-field">
            <label htmlFor="subject">Subject</label>
            <input
              id="subject"
              name="subject"
              required
              maxLength={200}
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
            />
          </div>
          <div className="form-field">
            <label htmlFor="message">Message</label>
            <textarea
              id="message"
              name="message"
              required
              maxLength={8000}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
            />
          </div>
          <button type="submit" className="btn" disabled={state === 'sending'}>
            {state === 'sending' ? 'Sending…' : 'Send message'}
          </button>
        </form>

        {state === 'ok' && <div className="status ok">Thanks — we got your message and will reply by email when we can.</div>}
        {state === 'err' && <div className="status err">{errMsg}</div>}
      </div>

      <p className="muted" style={{ marginTop: '1.5rem' }}>
        For account email confirmation, use the link from your signup email — it opens the confirmation page on this
        site.
      </p>
    </div>
  );
}
