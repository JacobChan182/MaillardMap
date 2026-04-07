import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { BrandMark } from './BrandMark';
import { useTheme } from '../theme/ThemeContext';

export function Layout({ children }: { children: ReactNode }) {
  const { theme, toggleTheme } = useTheme();
  const themeLabel = theme === 'dark' ? 'Light mode' : 'Dark mode';

  return (
    <div className="site">
      <header className="site-header">
        <div className="site-header__inner">
          <Link to="/" className="brand">
            <BrandMark size={34} />
            <span className="brand__text">
              MaillardMap
              <span> · food & friends</span>
            </span>
          </Link>
          <nav className="nav-links" aria-label="Main">
            <Link to="/support">Support</Link>
            <Link to="/privacy">Privacy</Link>
          </nav>
        </div>
      </header>
      <div className="site-main">{children}</div>
      <footer className="site-footer">
        <div className="site-footer__inner">
          <div>
            <p>
              <strong style={{ color: 'var(--text-secondary)' }}>MaillardMap</strong> — share where you eat with
              people you know.
            </p>
            <p style={{ marginTop: '0.5rem' }}>© {new Date().getFullYear()} MaillardMap</p>
            <button
              type="button"
              className="theme-toggle"
              onClick={toggleTheme}
              aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
            >
              {themeLabel}
            </button>
          </div>
          <div className="site-footer__links">
            <Link to="/support">Contact</Link>
            <Link to="/privacy">Privacy policy</Link>
            <Link to="/">Home</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
