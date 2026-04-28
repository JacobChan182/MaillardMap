import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { Layout } from './components/Layout';
import { HomePage } from './pages/HomePage';
import { PrivacyPage } from './pages/PrivacyPage';
import { ResetPasswordPage } from './pages/ResetPasswordPage';
import { SupportPage } from './pages/SupportPage';
import { VerifyEmailPage } from './pages/VerifyEmailPage';

function StripTrailingSlash({ to }: { to: string }) {
  const { search } = useLocation();
  return <Navigate to={{ pathname: to, search }} replace />;
}

export default function App() {
  const location = useLocation();
  const normalizedPath = location.pathname.replace(/\/+$/, '') || '/';
  const accountActionPage =
    normalizedPath === '/verify-email' ? (
      <VerifyEmailPage />
    ) : normalizedPath === '/reset-password' ? (
      <ResetPasswordPage />
    ) : null;

  if (accountActionPage) {
    return <Layout>{accountActionPage}</Layout>;
  }

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/support" element={<SupportPage />} />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/verify-email" element={<VerifyEmailPage />} />
        <Route path="/verify-email/" element={<StripTrailingSlash to="/verify-email" />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />
        <Route path="/reset-password/" element={<StripTrailingSlash to="/reset-password" />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
