class TrustedIssuer {
  final String did;
  final String name;
  final String category;

  const TrustedIssuer({
    required this.did,
    required this.name,
    required this.category,
  });
}

class TrustRegistryService {
  static const TrustedIssuer identityWalletIssuer = TrustedIssuer(
    did: 'did:example:issuer:identity-wallet-mvp',
    name: 'Identity Wallet MVP Issuer',
    category: 'Demo interno',
  );

  static const List<TrustedIssuer> trustedIssuers = [
    identityWalletIssuer,
    TrustedIssuer(
      did: 'did:key:z6MkkKZgsxAbqyWGdBUonDQFyLqNZdBtx8BACwmSQJ7KLLMi',
      name: 'Portal SSI Issuer',
      category: 'Portal de enrolamiento',
    ),
    TrustedIssuer(
      did: 'did:key:z6MkTrustedGovernmentIssuerDemo',
      name: 'Autoridad gubernamental demo',
      category: 'Gobierno',
    ),
    TrustedIssuer(
      did: 'did:key:z6MkTrustedEnterpriseIssuerDemo',
      name: 'Empresa verificada demo',
      category: 'Empresa',
    ),
  ];

  TrustedIssuer? findTrustedIssuer(String did) {
    for (final issuer in trustedIssuers) {
      if (issuer.did == did) return issuer;
    }
    return null;
  }

  bool isTrusted(String did) => findTrustedIssuer(did) != null;
}
