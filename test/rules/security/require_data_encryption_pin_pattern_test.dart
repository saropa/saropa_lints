import 'package:test/test.dart';

/// Mirrors [RequireDataEncryptionRule] pin detection; keep pattern in sync with
/// `_pinKeywordPattern` in security_auth_storage_rules.dart.
final RegExp _pinKeywordPattern = RegExp(r'(?<![a-zA-Z])pin');

/// Mirrors `_tokenKeywordPattern` in security_auth_storage_rules.dart. Bug:
/// `bugs/require_data_encryption_false_positive_search_index_tokens.md`.
final RegExp _tokenKeywordPattern = RegExp(
  r'(?<!search)'
  r'(?<!lexer)'
  r'(?<!parser)'
  r'(?<!word)'
  r'(?<!gram)'
  r'(?<!route)'
  r'(?<!csp)'
  r'(?<!index)'
  r'(?<!fts)'
  r'(?<!stop)'
  r'(?<!nlp)'
  r'(?<!lex)'
  r'tokens?',
);

/// Mirrors `_authKeywordPattern` in security_auth_storage_rules.dart.
final RegExp _authKeywordPattern = RegExp(r'auth(?!or(?!iz))');

/// Mirrors `_argumentEncryptionSignalPatterns` in security_auth_storage_rules.dart.
final List<RegExp> _argumentEncryptionSignalPatterns = <RegExp>[
  RegExp(r'\bsecure\b'),
  RegExp(r'\bencrypt\b'),
  RegExp(r'\bencryptedbox\b'),
  RegExp(r'\bencrypted\w*'),
  RegExp(r'\bcipher\w*'),
  RegExp(r'\baes\w*'),
  RegExp(r'encrypted\('),
];

/// Mirrors `_argumentSearchIndexContextPatterns` in security_auth_storage_rules.dart.
final List<RegExp> _argumentSearchIndexContextPatterns = <RegExp>[
  RegExp(r'searchtokens?\b'),
  RegExp(r'searchindex(?:es)?\b'),
  RegExp(r'lookuptokens?\b'),
  RegExp(r'lookupindex(?:es)?\b'),
  RegExp(r'lexertokens?\b'),
  RegExp(r'parsertokens?\b'),
  RegExp(r'wordtokens?\b'),
  RegExp(r'(?:n)?gramtokens?\b'),
  RegExp(r'routetokens?\b'),
  RegExp(r'csptokens?\b'),
  RegExp(r'indextokens?\b'),
  RegExp(r'ftstokens?\b'),
  RegExp(r'stoptokens?\b'),
  RegExp(r'nlptokens?\b'),
];

bool _argsHaveEncryptionSignal(String argsSource) {
  final String lower = argsSource.toLowerCase();
  return _argumentEncryptionSignalPatterns.any((RegExp p) => p.hasMatch(lower));
}

bool _argsHaveSearchIndexContext(String argsSource) {
  final String lower = argsSource.toLowerCase();
  return _argumentSearchIndexContextPatterns.any(
    (RegExp p) => p.hasMatch(lower),
  );
}

void main() {
  group('require_data_encryption pin keyword guard', () {
    test('does not match pin inside OwaspMapping / mapping (regression)', () {
      const args =
          'projectroot: projectroot, data: x, owasplookup: const <string, owaspmapping>{}';
      expect(_pinKeywordPattern.hasMatch(args), isFalse);
    });

    test('does not match pin inside shopping (embedded p-p-i-n)', () {
      expect(_pinKeywordPattern.hasMatch('label: shopping_cart'), isFalse);
    });

    test('matches standalone pin token (before state)', () {
      expect(_pinKeywordPattern.hasMatch('pin: value'), isTrue);
      expect(_pinKeywordPattern.hasMatch('named: pin, value: 1'), isTrue);
    });

    test(
      'does not match userpin / camelCase without delimiter (after state)',
      () {
        expect(_pinKeywordPattern.hasMatch('userpin: 1'), isFalse);
        expect(_pinKeywordPattern.hasMatch('mypincode: 1'), isFalse);
      },
    );

    test('matches pin after non-letter delimiter', () {
      expect(_pinKeywordPattern.hasMatch(r'x.pin: 1'), isTrue);
      expect(_pinKeywordPattern.hasMatch('user_pin: 1'), isTrue);
      expect(_pinKeywordPattern.hasMatch('(pin)'), isTrue);
    });

    test(
      'matches pin at start of argument text (pinCode-style identifiers)',
      () {
        expect(_pinKeywordPattern.hasMatch('pincode: x'), isTrue);
      },
    );

    // -- Edge-case documentation: accepted trade-offs --

    test('matches pin-prefix words like pineapple (accepted trade-off)', () {
      // Words starting with "pin" match because no lookahead is used — this is
      // tolerated so genuine fields like pinCode / pinNumber are caught.
      expect(_pinKeywordPattern.hasMatch('label: pineapple'), isTrue);
      expect(_pinKeywordPattern.hasMatch('label: pinball'), isTrue);
    });

    test('does not match words with pin embedded after a letter', () {
      // opinion = o-p-i-n → 'pin' at offset 1 is preceded by 'o' (letter).
      // spinning = …p-p-i-n → preceded by 'p' (letter).
      expect(_pinKeywordPattern.hasMatch('opinion: value'), isFalse);
      expect(_pinKeywordPattern.hasMatch('spinning: value'), isFalse);
    });

    test('matches pin preceded by digit (digit is not a letter)', () {
      expect(_pinKeywordPattern.hasMatch('code1234pin: x'), isTrue);
    });
  });

  group('require_data_encryption argument encryption signal', () {
    test('matches Drift-style companion with encrypted* value', () {
      const args =
          '_driftlikecompanion(privatekey: _driftvalue(encryptedprivatekey), publickey: _driftvalue(""))';
      expect(_argsHaveEncryptionSignal(args), isTrue);
    });

    test('matches …encrypted( method name on arg text', () {
      expect(
        _argsHaveEncryptionSignal(
          '_driftlikecompanion(privatekey: _driftvalue(tofirebaseencrypted(x)))',
        ),
        isTrue,
      );
    });

    test('matches cipher* and aes* identifiers', () {
      expect(_argsHaveEncryptionSignal('x(ciphertext, y)'), isTrue);
      expect(
        _argsHaveEncryptionSignal('token: value(aesencodedtoken)'),
        isTrue,
      );
    });

    test(
      'does not match unencrypted as a single identifier (no false escape)',
      () {
        expect(
          _argsHaveEncryptionSignal('privatekey: value(unencrypted)'),
          isFalse,
        );
      },
    );

    test('matches secure/encrypt in args (symmetric with receiver check)', () {
      expect(_argsHaveEncryptionSignal('key: x, value: secure'), isTrue);
    });
  });

  // Regression: bug
  // `require_data_encryption_false_positive_search_index_tokens.md`. The bare
  // `'token'` substring used to flag any identifier containing it — including
  // `searchTokens`, `lexerTokens`, `parserTokens`, `wordTokens`, `nGramTokens`,
  // `routeTokens`, `cspTokens`. None are credentials.
  group('require_data_encryption token keyword guard', () {
    test('does NOT match search-index identifiers (the reported bug)', () {
      expect(_tokenKeywordPattern.hasMatch('searchtoken'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('searchtokens'), isFalse);
    });

    test('does NOT match compiler / parser / NLP token identifiers', () {
      expect(_tokenKeywordPattern.hasMatch('lexertokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('parsertokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('wordtokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('gramtokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('lextokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('nlptokens'), isFalse);
    });

    test('does NOT match routing / CSP / FTS / stop / index tokens', () {
      expect(_tokenKeywordPattern.hasMatch('routetokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('csptokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('indextokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('ftstokens'), isFalse);
      expect(_tokenKeywordPattern.hasMatch('stoptokens'), isFalse);
    });

    test('STILL matches real credential-context tokens', () {
      // None of the safe-context prefixes precede `token` here.
      expect(_tokenKeywordPattern.hasMatch('authtoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('apitoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('accesstoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('refreshtoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('bearertoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('jwttoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('csrftoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('sessiontoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('oauthtoken'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('idtoken'), isTrue);
    });

    test('matches bare token / tokens (no excluded prefix at boundary)', () {
      expect(_tokenKeywordPattern.hasMatch("'token', 'value'"), isTrue);
      expect(_tokenKeywordPattern.hasMatch('(tokens)'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('value: token'), isTrue);
    });

    test('matches plural token form (tokens) the same as singular', () {
      expect(_tokenKeywordPattern.hasMatch('apitokens'), isTrue);
      expect(_tokenKeywordPattern.hasMatch('searchtokens'), isFalse);
    });
  });

  // Regression: substring `auth` flagged `author`, `authority`, `authorship`,
  // `authored`, `authoring` — publishing, governance and attribution terms
  // with no credential meaning. Lookahead `(?!or(?!iz))` keeps `authorize` /
  // `authorization` / `unauthorized` matching while excluding the rest.
  group('require_data_encryption auth keyword guard', () {
    test('does NOT match author / authoring / authorship / authored', () {
      expect(_authKeywordPattern.hasMatch('author'), isFalse);
      expect(_authKeywordPattern.hasMatch('authoring'), isFalse);
      expect(_authKeywordPattern.hasMatch('authorship'), isFalse);
      expect(_authKeywordPattern.hasMatch('authored'), isFalse);
      expect(_authKeywordPattern.hasMatch('authorshipmetadata'), isFalse);
      expect(_authKeywordPattern.hasMatch('authorprefix'), isFalse);
    });

    test('does NOT match authority / authorities / authoritarian', () {
      // Governmental jurisdiction lookups in the bug report.
      expect(_authKeywordPattern.hasMatch('authority'), isFalse);
      expect(_authKeywordPattern.hasMatch('authorities'), isFalse);
      expect(_authKeywordPattern.hasMatch('authoritarian'), isFalse);
    });

    test('STILL matches authorize / authorization / unauthorized', () {
      // The `or(?!iz)` exception preserves real auth verbs.
      expect(_authKeywordPattern.hasMatch('authorize'), isTrue);
      expect(_authKeywordPattern.hasMatch('authorization'), isTrue);
      expect(_authKeywordPattern.hasMatch('unauthorized'), isTrue);
    });

    test('STILL matches authToken / apiAuth / oauth / authenticate', () {
      expect(_authKeywordPattern.hasMatch('authtoken'), isTrue);
      expect(_authKeywordPattern.hasMatch('apiauth'), isTrue);
      expect(_authKeywordPattern.hasMatch('oauth'), isTrue);
      expect(_authKeywordPattern.hasMatch('authentic'), isTrue);
      expect(_authKeywordPattern.hasMatch('authentication'), isTrue);
      expect(_authKeywordPattern.hasMatch('authenticate'), isTrue);
    });

    test('matches bare auth at any position', () {
      expect(_authKeywordPattern.hasMatch("'auth'"), isTrue);
      expect(_authKeywordPattern.hasMatch('key: auth'), isTrue);
    });
  });

  // Regression: bare `tokens` value variable (e.g., `Companion(searchTokens:
  // Value(tokens))`). The field name in the same call disambiguates intent.
  group('require_data_encryption argument search-index context', () {
    test('detects searchTokens / searchIndex field anywhere in args', () {
      expect(
        _argsHaveSearchIndexContext(
          'startrekcharacterscompanion(searchtokens: value<string?>(tokens))',
        ),
        isTrue,
      );
      expect(
        _argsHaveSearchIndexContext("'searchindex', 'a|b|c'"),
        isTrue,
      );
      expect(
        _argsHaveSearchIndexContext('companion(searchindexes: value(x))'),
        isTrue,
      );
    });

    test('detects compiler / parser / routing field names in args', () {
      expect(_argsHaveSearchIndexContext('c(lexertokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(parsertokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(wordtokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(gramtokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(ngramtokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(routetokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(csptokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(indextokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(ftstokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(stoptokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(nlptokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(lookuptokens: x)'), isTrue);
      expect(_argsHaveSearchIndexContext('c(lookupindex: x)'), isTrue);
    });

    test('does NOT trigger on credential field names', () {
      // Real auth-token storage must NOT be silenced by this check.
      expect(_argsHaveSearchIndexContext("'authtoken', 'value'"), isFalse);
      expect(_argsHaveSearchIndexContext("c(apitoken: x)"), isFalse);
      expect(_argsHaveSearchIndexContext("'session_token', 'x'"), isFalse);
    });
  });
}
