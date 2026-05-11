import { Link } from 'react-router-dom';

const IOS_BETA_TESTFLIGHT_URL = 'https://testflight.apple.com/join/acu9qcwU';

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
          <a
            href={IOS_BETA_TESTFLIGHT_URL}
            className="btn"
            target="_blank"
            rel="noopener noreferrer"
          >
            Join iOS beta (TestFlight)
          </a>
          <Link to="/support" className="btn btn-ghost">
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
        <div className="page-cta__platforms">
          <div className="page-cta__ios">
            <h2 className="page-cta__platform-head">iOS</h2>
            <p>Join the beta on TestFlight.</p>
            <a
              href={IOS_BETA_TESTFLIGHT_URL}
              className="btn"
              target="_blank"
              rel="noopener noreferrer"
            >
              Join iOS beta (TestFlight)
            </a>
          </div>
          <div className="page-cta__android">
            <h2 className="page-cta__platform-head">Android</h2>
            <p>Still in development — check back later.</p>
          </div>
        </div>
      </div>
    </main>
  );
}
