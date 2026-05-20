import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:identity_wallet_mvp/core/services/wallet_enrollment_service.dart';

void main() {
  test('detects and parses portal access invitation QR payload', () {
    final qrPayload = jsonEncode({
      'type': 'ssi_wallet_access_invitation',
      'version': '2.0',
      'enrollment_id': '4dce1a23-220e-41f4-8af3-49e2feb84db3',
      'offer_nonce': 'nonce-from-portal',
      'issuer_did': 'did:key:z6MkkKZgsxAbqyWGdBUonDQFyLqNZdBtx8BACwmSQJ7KLLMi',
      'wallet_action': 'scan_to_register_account_and_get_access',
      'account': {
        'name': 'Marisol Navarro Torres',
        'email': 'mnavarro@seguridata.com',
        'alias': 'Marr',
        'account_type': 'personal',
        'access_scopes': ['mobile_app:signup', 'wallet:access'],
      },
      'did_registration_required': false,
      'auto_register_on_complete': true,
      'did_registration_endpoint':
          'http://127.0.0.1:8010/api/did-registry/register',
      'access_invitation_url':
          'http://127.0.0.1:8010/api/access/invitations/4dce1a23-220e-41f4-8af3-49e2feb84db3',
      'complete_signup_endpoint':
          'http://127.0.0.1:8010/api/access/invitations/4dce1a23-220e-41f4-8af3-49e2feb84db3/complete',
      'credential_request_endpoint':
          'http://127.0.0.1:8010/api/enrollment/4dce1a23-220e-41f4-8af3-49e2feb84db3/issue-credential',
    });

    expect(
      WalletEnrollmentService.looksLikeEnrollmentPayload(qrPayload),
      isTrue,
    );

    final invitation = WalletEnrollmentInvitation.fromJson(
      jsonDecode(qrPayload) as Map<String, dynamic>,
    );

    expect(invitation.enrollmentId, '4dce1a23-220e-41f4-8af3-49e2feb84db3');
    expect(invitation.holderName, 'Marisol Navarro Torres');
    expect(invitation.email, 'mnavarro@seguridata.com');
    expect(invitation.offerNonce, 'nonce-from-portal');
    expect(invitation.didRegistrationRequired, isFalse);
    expect(invitation.autoRegisterOnComplete, isTrue);
    expect(invitation.didRegistrationEndpoint, contains('/api/did-registry'));
    expect(invitation.accessScopes, contains('wallet:access'));
    expect(invitation.issueEndpoints, hasLength(2));
    expect(invitation.allowedCurve, 'Ed25519');
  });

  test('parses resolved portal credential offer with claims and endpoints', () {
    final credentialOffer = {
      'type': 'ssi_wallet_access_invitation',
      'version': '2.0',
      'wallet_action': 'scan_to_register_account_and_get_access',
      'enrollment_id': '4dce1a23-220e-41f4-8af3-49e2feb84db3',
      'offer_nonce': 'nonce-from-portal',
      'created_at': '2026-05-14T15:10:25.305499+00:00',
      'expires_at': '2026-05-21T15:10:25.305499+00:00',
      'access': {
        'status': 'pending_mobile_signup',
        'scopes': ['mobile_app:signup', 'wallet:access'],
      },
      'issuer': {
        'name': 'Portal SSI Issuer',
        'did': 'did:key:z6MkkKZgsxAbqyWGdBUonDQFyLqNZdBtx8BACwmSQJ7KLLMi',
      },
      'did_registration': {
        'required': true,
        'register_endpoint': 'http://127.0.0.1:8010/api/did-registry/register',
      },
      'access_invitation_url':
          'http://127.0.0.1:8010/api/access/invitations/4dce1a23-220e-41f4-8af3-49e2feb84db3',
      'complete_signup_endpoint':
          'http://127.0.0.1:8010/api/access/invitations/4dce1a23-220e-41f4-8af3-49e2feb84db3/complete',
      'credential_request_endpoint':
          'http://127.0.0.1:8010/api/enrollment/4dce1a23-220e-41f4-8af3-49e2feb84db3/issue-credential',
      'claims_preview': {
        'name': 'Marisol Navarro Torres',
        'email': 'mnavarro@seguridata.com',
        'alias': 'Marr',
        'accountType': 'personal',
        'certificateSha256':
            '2b0d9211e06bd9fbaf43ef1d7498c9028847ebeff40e6a7cd091cde0997bc1a6',
        'keySha256':
            'bbacde407d87a6dab229ebd2a7ce442525134235b4fde1dca95d84b18fcebdbc',
      },
    };

    final invitation = WalletEnrollmentInvitation.fromJson(credentialOffer);

    expect(invitation.holderName, 'Marisol Navarro Torres');
    expect(invitation.email, 'mnavarro@seguridata.com');
    expect(invitation.alias, 'Marr');
    expect(invitation.accountTypeLabel, 'Personal');
    expect(
      invitation.didRegistrationEndpoint,
      contains('/api/did-registry/register'),
    );
    expect(invitation.issueEndpoints, hasLength(2));
    expect(invitation.accessScopes, contains('wallet:access'));
    expect(invitation.expiresAt, isNotNull);
  });
}
