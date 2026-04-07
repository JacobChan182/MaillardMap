import { Link } from 'react-router-dom';

export function HomePage() {
  return (
    <main className="page">
      <section className="hero">
        <span className="badge">Official site</span>
        <h1 className="hero__title">Your map for eating out together.</h1>
        <p className="hero__sub">
          MaillardMap is a social layer for restaurants: quick posts from real places, a live map of where your crew has
          been, and tools to plan the next table without the noise of endless anonymous reviews.
        </p>
        <div className="hero-actions">
          <Link to="/support" className="btn">
            Get in touch
          </Link>
          <Link to="/privacy" className="btn btn-ghost">
            How we use data
          </Link>
        </div>

        <div className="feature-grid">
          <div className="feature-card">
            <div className="feature-card__icon" aria-hidden>
              📍
            </div>
            <h3>On the map</h3>
            <p>See visits and saves on a map that scales from heat to pins — same context as in the app.</p>
          </div>
          <div className="feature-card">
            <div className="feature-card__icon" aria-hidden>
              🤝
            </div>
            <h3>Friends first</h3>
            <p>Built around people you actually know — not stars from strangers.</p>
          </div>
          <div className="feature-card">
            <div className="feature-card__icon" aria-hidden>
              ✉️
            </div>
            <h3>Human support</h3>
            <p>Questions about your account or email confirmation? We read what you send.</p>
          </div>
        </div>
      </section>

      <div className="page-cta">
        <p>Download the iOS app from the App Store when it&apos;s live — this page is for policy, help, and email verification.</p>
        <Link to="/support" className="btn">
          Contact support
        </Link>
      </div>
    </main>
  );
}
