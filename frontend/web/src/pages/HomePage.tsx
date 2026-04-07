import { Link } from 'react-router-dom';

export function HomePage() {
  return (
    <div className="page">
      <span className="badge">Official site</span>
      <h1>MaillardMap</h1>
      <p className="lead">
        Social restaurant map — share visits with friends, explore on the map, and blend tastes for your next spot.
      </p>
      <p>
        Use the links below for account help or to read how we handle data. Download the app from the App Store when
        available.
      </p>
      <div className="hero-actions">
        <Link to="/support" className="btn">
          Contact support
        </Link>
        <Link to="/privacy" className="btn btn-ghost">
          Privacy policy
        </Link>
      </div>
    </div>
  );
}
