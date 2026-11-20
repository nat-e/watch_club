import {describe, expect, it} from 'vitest';
import {parseMaxUses} from '../../src/accounts/invitations';

describe('parseMaxUses', () => {
  it('reads a whole number from 1', () => {
    expect(parseMaxUses(' 12 ')).toBe(12);
    expect(parseMaxUses('1')).toBe(1);
  });

  it('reads a blank field as no limit', () => {
    expect(parseMaxUses('')).toBeNull();
    expect(parseMaxUses('  ')).toBeNull();
  });

  it('refuses anything else', () => {
    for (const text of ['0', '-1', '1.5', '1e3', 'ten']) {
      expect(parseMaxUses(text), text).toBeUndefined();
    }
  });
});
