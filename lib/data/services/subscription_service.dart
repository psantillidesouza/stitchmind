import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'api_client.dart';

/// Camada de assinatura (RevenueCat) + status premium no backend.
///
/// É um [ChangeNotifier] para a UI/router reagirem quando o usuário
/// assina/expira. O acesso premium vale se QUALQUER uma destas for verdadeira:
///  - RevenueCat tem entitlement/assinatura ativa (`_rcActive`);
///  - o banco diz que o usuário é premium (`_serverPremium`, via /auth/me ou
///    webhook do RevenueCat);
///  - o override de DEBUG está ligado.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService(this._api);

  final ApiClient _api;

  // ─── DEBUG: libera TODAS as funções premium em builds de debug ──────
  // false = o app usa o status premium REAL também em debug/simulador
  // (cadeado nas aulas premium, paywall, etc. aparecem como em produção).
  static const bool _kDebugUnlockPremium = false;
  static bool get _debugUnlock => kDebugMode && _kDebugUnlockPremium;

  // Chaves públicas (Public API Key) por plataforma — RevenueCat.
  static const _appleKey = 'appl_fYeXbnMUoVuvklIzcWoitPTEPZF';
  static const _googleKey = 'goog_TVXujtYHBrGBivwsTsaBrhmUYtf';

  static String get _apiKey =>
      defaultTargetPlatform == TargetPlatform.android ? _googleKey : _appleKey;

  // IDs dos produtos (fallback quando não há offering configurado no painel).
  static const productIds = <String>[
    'com.stitchmind.semanal',
    'com.stitchmind.anual',
  ];

  /// Offering da oferta de saída: plano anual com 3 dias de teste grátis
  /// (mostrado quando o usuário fecha o paywall principal sem assinar).
  /// iOS usa o produto dedicado `com.stitchmind.anualtrial`; Android usa o
  /// `com.stitchmind.anual` com a oferta de trial abaixo.
  static const annualTrialOfferingId = 'annual_trial';

  /// Offer id do trial na Play Console. A oferta é tageada `rc-ignore-offer`
  /// pra NÃO ser aplicada nas compras do paywall principal — aqui a gente
  /// seleciona ela explicitamente.
  static const _googleTrialOfferId = 'com-stitchmind-anualtrial';

  bool _rcActive = false; // RevenueCat: entitlement/assinatura ativa
  bool _serverPremium = false; // banco: users.is_premium

  /// Acesso premium efetivo (qualquer fonte verdadeira).
  bool get isSubscribed => _rcActive || _serverPremium || _debugUnlock;

  /// Premium REAL (RevenueCat ou banco) — ignora o desbloqueio de debug.
  /// Usado para decidir se a paywall aparece (em debug ela ainda aparece p/
  /// teste, mesmo com as funções premium liberadas).
  bool get isReallyPremium => _rcActive || _serverPremium;

  bool _ready = false;
  bool get ready => _ready;

  bool _configured = false;

  /// Configura o SDK e lê o estado inicial. Chamado uma vez no boot.
  Future<void> init() async {
    try {
      await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
      // Pré-aquece a busca de produtos (offerings + StoreKit/Play) em
      // background: a 1ª consulta à loja pode levar vários segundos, e assim
      // ela corre durante o boot — o paywall abre com os planos já em cache.
      // (Não usa await de propósito: não pode atrasar o boot.)
      products();
    } catch (e) {
      if (kDebugMode) debugPrint('SM_SUB: falha ao iniciar RevenueCat: $e');
      _rcActive = false;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  void _apply(CustomerInfo info) {
    // Abre o gate com QUALQUER entitlement ativo OU qualquer assinatura ativa —
    // assim funciona mesmo que o entitlement não esteja mapeado no painel.
    final product = info.activeSubscriptions.isNotEmpty
        ? info.activeSubscriptions.first
        : null;
    _rcActive = info.entitlements.active.isNotEmpty ||
        info.activeSubscriptions.isNotEmpty;
    notifyListeners();
    // Espelha o status de assinatura no banco (best-effort; exige login).
    _syncToServer(product);
  }

  /// Envia o status real (RevenueCat) para o backend gravar em users.is_premium.
  /// Sem login, o endpoint responde 401 e o postSilentJson devolve null.
  Future<void> _syncToServer(String? product) async {
    final res = await _api.postSilentJson('/v1/subscription/sync', {
      'is_premium': _rcActive,
      if (product != null) 'product': product,
    });
    if (res != null && res['is_premium'] is bool) {
      final v = res['is_premium'] as bool;
      if (v != _serverPremium) {
        _serverPremium = v;
        notifyListeners();
      }
    }
  }

  /// Lê users.is_premium do backend (ex.: premium concedido via webhook) e
  /// atualiza o acesso. Chamar após o login.
  Future<void> refreshFromServer() async {
    try {
      final json = await _api.get('/v1/auth/me');
      final user = (json is Map) ? json['user'] : null;
      if (user is Map && user['is_premium'] is bool) {
        final v = user['is_premium'] as bool;
        if (v != _serverPremium) {
          _serverPremium = v;
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SM_SUB: falha ao ler is_premium: $e');
    }
  }

  // Uma busca por vez: chamadas concorrentes esperam o MESMO future (não é
  // cache — toda exibição consulta o RevenueCat; o SDK gerencia o próprio
  // cache de offerings).
  Future<List<StoreProduct>>? _productsFetch;

  /// Produtos disponíveis para compra — SEMPRE via RevenueCat (nenhum cache
  /// no app). O warm-up do [init] deixa o SDK com a resposta pronta.
  Future<List<StoreProduct>> products() {
    if (!_configured) return Future.value(const []);
    return _productsFetch ??= _fetchProducts().whenComplete(() {
      _productsFetch = null;
    });
  }

  /// Busca crua: pacotes do offering "current" se houver; senão direto pelos
  /// [productIds] (útil em StoreKit testing / offering não montado no painel).
  Future<List<StoreProduct>> _fetchProducts() async {
    try {
      final current = (await Purchases.getOfferings()).current;
      final fromOffering =
          current?.availablePackages.map((p) => p.storeProduct).toList() ??
              const <StoreProduct>[];
      if (fromOffering.isNotEmpty) return fromOffering;
    } catch (e) {
      if (kDebugMode) debugPrint('SM_SUB: sem offering, tentando IDs: $e');
    }
    try {
      return await Purchases.getProducts(productIds);
    } catch (e) {
      if (kDebugMode) debugPrint('SM_SUB: falha ao buscar produtos: $e');
      return const [];
    }
  }

  /// Package anual do offering [annualTrialOfferingId], ou null se o offering
  /// não existir / estiver sem produtos / sem rede.
  Future<Package?> annualTrialPackage() async {
    if (!_configured) return null;
    try {
      final offering =
          (await Purchases.getOfferings()).getOffering(annualTrialOfferingId);
      if (offering == null) return null;
      return offering.annual ??
          (offering.availablePackages.isNotEmpty
              ? offering.availablePackages.first
              : null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SM_SUB: falha ao buscar offering $annualTrialOfferingId: $e');
      }
      return null;
    }
  }

  /// Compra a oferta de saída. No Android seleciona explicitamente a oferta
  /// de trial ([_googleTrialOfferId]) — ela é tageada `rc-ignore-offer`, então
  /// o SDK não a aplicaria sozinho. No iOS o trial é intro offer do próprio
  /// produto, basta comprar o package. Retorna true se ficou assinante.
  Future<bool> purchaseAnnualTrial(Package pkg) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final options =
            pkg.storeProduct.subscriptionOptions ?? const <SubscriptionOption>[];
        SubscriptionOption? trial;
        for (final o in options) {
          if (o.id.endsWith(':$_googleTrialOfferId')) {
            trial = o;
            break;
          }
          // Fallback: qualquer oferta (não base plan) com fase grátis.
          if (!o.isBasePlan && o.freePhase != null) trial ??= o;
        }
        if (trial != null) {
          _apply(await Purchases.purchaseSubscriptionOption(trial));
          return isSubscribed;
        }
      }
      _apply(await Purchases.purchasePackage(pkg));
      return isSubscribed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// Compra um produto (paywall principal). Retorna true se ficou assinante,
  /// false se o usuário cancelou.
  ///
  /// Android: compra explicitamente o BASE PLAN, nunca uma oferta — a oferta
  /// de trial ([_googleTrialOfferId]) existe no mesmo plano anual e o SDK a
  /// aplicaria por padrão; ela é exclusiva da tela de saída
  /// ([purchaseAnnualTrial]).
  Future<bool> purchase(StoreProduct product) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final options =
            product.subscriptionOptions ?? const <SubscriptionOption>[];
        for (final o in options) {
          if (o.isBasePlan) {
            _apply(await Purchases.purchaseSubscriptionOption(o));
            return isSubscribed;
          }
        }
      }
      await Purchases.purchaseStoreProduct(product);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
    _apply(await Purchases.getCustomerInfo());
    return isSubscribed;
  }

  /// Restaura compras anteriores. Retorna true se reativou algum entitlement.
  Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    _apply(info);
    return isSubscribed;
  }

  /// Desassocia o usuário do RevenueCat (no logout) e zera o estado premium —
  /// evita que a próxima conta no mesmo aparelho herde entitlements.
  Future<void> logOut() async {
    if (_configured) {
      try {
        await Purchases.logOut();
      } catch (_) {/* já era anônimo, ignora */}
    }
    _rcActive = false;
    _serverPremium = false;
    notifyListeners();
  }

  /// Associa a compra (feita anônima, antes do login) ao usuário do Firebase
  /// e sincroniza o status premium com o banco.
  Future<void> identify(String uid) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(uid);
      _apply(result.customerInfo); // dispara o sync para o banco
      await refreshFromServer(); // puxa is_premium (inclusive via webhook)
    } catch (e) {
      if (kDebugMode) debugPrint('SM_SUB: falha ao identificar usuário: $e');
    }
  }
}
