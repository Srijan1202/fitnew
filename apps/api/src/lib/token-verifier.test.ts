/**
 * Phase 19 (ADR-025): the server reaches Firebase with a key file (the LAN
 * PC, the hosted fallback) or, on AWS, with a Workload Identity Federation
 * configuration — a file with no secret in it.
 */
import { describe, expect, it } from 'vitest';

import { VerifiedTokenCache, credentialFileKind } from './token-verifier.js';

describe('credentialFileKind', () => {
  it('a service-account key is used as a key', () => {
    expect(credentialFileKind({ type: 'service_account', project_id: 'p', private_key: 'k', client_email: 'e' })).toBe('service-account');
  });

  it('a federation configuration (AWS → Google) goes to Google\'s own auth library', () => {
    expect(
      credentialFileKind({
        type: 'external_account',
        audience: '//iam.googleapis.com/projects/1/locations/global/workloadIdentityPools/fitos/providers/aws',
        subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
        token_url: 'https://sts.googleapis.com/v1/token',
        credential_source: { environment_id: 'aws1', regional_cred_verification_url: 'https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15', imdsv2_session_token_url: 'http://169.254.169.254/latest/api/token' },
      }),
    ).toBe('application-default');
  });

  it('anything unrecognised is left to the auth library, which reports what is wrong', () => {
    expect(credentialFileKind({})).toBe('application-default');
    expect(credentialFileKind(null)).toBe('application-default');
  });
});

describe('VerifiedTokenCache (beta 6.2, audit S9)', () => {
  const who = (uid: string) => ({ uid, email: null, emailVerified: false, claims: {} });

  it('a verified token is trusted for a minute, never past its own expiry', () => {
    let now = 1_000_000;
    const c = new VerifiedTokenCache(60_000, 10, () => now);
    c.set('tok-a', who('a'), now + 3_600_000);
    expect(c.get('tok-a')?.uid).toBe('a');
    now += 59_999;
    expect(c.get('tok-a')?.uid).toBe('a');
    now += 1;
    expect(c.get('tok-a')).toBeNull();
    expect(c.size).toBe(0);
    // A token that expires sooner is kept only that long; one already expired is not kept.
    c.set('tok-b', who('b'), now + 10_000);
    now += 10_000;
    expect(c.get('tok-b')).toBeNull();
    c.set('tok-c', who('c'), now);
    expect(c.size).toBe(0);
    expect(c.get('never-seen')).toBeNull();
  });

  it('forgetting a person drops all their tokens, and nobody else’s', () => {
    const c = new VerifiedTokenCache(60_000, 10, () => 0);
    c.set('a1', who('a'), 1e12);
    c.set('a2', who('a'), 1e12);
    c.set('b1', who('b'), 1e12);
    c.forgetUid('a');
    expect(c.get('a1')).toBeNull();
    expect(c.get('a2')).toBeNull();
    expect(c.get('b1')?.uid).toBe('b');
  });

  it('when full, expired entries go first, then the oldest', () => {
    let now = 0;
    const c = new VerifiedTokenCache(60_000, 2, () => now);
    c.set('old', who('o'), 1e12);
    now = 30_000;
    c.set('mid', who('m'), 1e12);
    now = 61_000; // 'old' has expired
    c.set('new', who('n'), 1e12);
    expect(c.size).toBe(2);
    expect(c.get('mid')?.uid).toBe('m');
    c.set('newest', who('x'), 1e12); // none expired: the oldest ('mid') goes
    expect(c.get('mid')).toBeNull();
    expect(c.get('new')?.uid).toBe('n');
    expect(c.get('newest')?.uid).toBe('x');
  });
});
