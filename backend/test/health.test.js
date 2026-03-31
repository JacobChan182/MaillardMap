import { describe, expect, it } from 'vitest';
import { getHealth } from '../src/modules/health/health.service.js';
describe('health', () => {
    it('returns ok response', () => {
        const health = getHealth();
        expect(health.ok).toBe(true);
        expect(health.service).toBe('bigback-api');
        expect(typeof health.time).toBe('string');
    });
});
