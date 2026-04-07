import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';

export function Layout({ children }: { children: ReactNode }) {
  return (
    <>
      <header
        style={{
          borderBottom: '1px solid var(--border)',
          background: 'var(--bg-elevated)',
        }}
      >
        <div
          style={{
            maxWidth: '56rem',
            margin: '0 auto',
            padding: '0.9rem 1.25rem',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '1rem',
            flexWrap: 'wrap',
          }}
        >
          <Link to="/" style={{ fontWeight: 700, color: 'var(--text)', textDecoration: 'none' }}>
            MaillardMap
          </Link>
          <nav className="nav-links">
            <Link to="/support">Support</Link>
            <Link to="/privacy">Privacy</Link>
          </nav>
        </div>
      </header>
      <main>{children}</main>
      <footer style={{ padding: '2rem 1.25rem', textAlign: 'center' }} className="muted">
        © {new Date().getFullYear()} MaillardMap
      </footer>
    </>
  );
}
