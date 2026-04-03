export function getHealth() {
  return {
    ok: true,
    service: 'maillardmap-api',
    time: new Date().toISOString(),
  };
}

