/**
 * Phase 19 (ADR-025): the server reaches Firebase with a key file (the LAN
 * PC, the hosted fallback) or, on AWS, with a Workload Identity Federation
 * configuration — a file with no secret in it.
 */
import { describe, expect, it } from 'vitest';

import { credentialFileKind } from './token-verifier.js';

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
