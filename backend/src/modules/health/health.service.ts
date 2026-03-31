export function getHealth() {
  return {
    ok: true,
    service: 'bigback-api',
    time: new Date().toISOString(),
  };
}

