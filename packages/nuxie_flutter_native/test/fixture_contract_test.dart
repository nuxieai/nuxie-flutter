import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter_native/src/bridge_mappers.dart';
import 'package:nuxie_flutter_native/src/generated/nuxie_bridge.g.dart';
import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

void main() {
  final actions =
      jsonDecode(File('test/fixtures/app-action.json').readAsStringSync())
          as Map;
  for (final vector in actions['vectors'] as List) {
    test('native App Action fixture: ${vector['name']}', () {
      final expected = vector['expect'] as Map;
      final experience = expected['experience'] as Map;
      final result = fromAppAction(
        PAppAction(
          name: expected['name'] as String,
          payload: (expected['payload'] as Map?)?.cast<String?, Object?>(),
          experience: PExperienceRef(
            experienceId: experience['experienceId'] as String,
            experienceVersion: experience['experienceVersion'] as String?,
            journeyId: experience['journeyId'] as String?,
          ),
        ),
      );
      expect(result.name, expected['name']);
      expect(result.payload, expected['payload']);
      expect(result.experience.experienceId, experience['experienceId']);
      expect(
        result.experience.experienceVersion,
        experience['experienceVersion'],
      );
      expect(result.experience.journeyId, experience['journeyId']);
    });
  }
  final consumptions =
      jsonDecode(
            File('test/fixtures/feature-consumption.json').readAsStringSync(),
          )
          as Map;
  for (final vector in consumptions['vectors'] as List) {
    test('native consumption fixture: ${vector['name']}', () {
      final response = vector['response'] as Map;
      final result = fromFeatureConsumptionResult(
        PFeatureConsumptionResult(
          operationId: response['operationId'] as String,
          customerId: response['customerId'] as String,
          featureId: response['featureId'] as String,
          occurredAtMs: (response['occurredAtMs'] as num?)?.toDouble(),
          accepted: response['accepted'] as bool,
          code: response['code'] as String,
          quantity: (response['quantity'] as num).toDouble(),
          balance: (response['balance'] as num?)?.toDouble(),
          unlimited: response['unlimited'] as bool,
          active: response['active'] as bool,
          idempotentReplay: response['idempotentReplay'] as bool,
        ),
      );
      expect(result.accepted, response['accepted']);
      expect(result.active, response['active']);
      expect(result.balance, response['balance']);
      expect(result.idempotentReplay, response['idempotentReplay']);
      expect(result.operationId, response['operationId']);
      expect(result.customerId, response['customerId']);
      expect(result.featureId, response['featureId']);
      expect(result.occurredAtMs, response['occurredAtMs']);
      expect(result.quantity, response['quantity']);
    });
  }
  test('consumption receipt retains a missing historical timestamp', () {
    final result = fromFeatureConsumptionResult(
      PFeatureConsumptionResult(
        operationId: 'historical',
        customerId: 'customer',
        featureId: 'credits',
        accepted: true,
        code: 'consumed',
        quantity: 1,
        balance: 0,
        unlimited: false,
        active: false,
        idempotentReplay: true,
      ),
    );
    expect(result.occurredAtMs, isNull);
  });
  test('consumption receipt requires customer and Feature identity', () {
    for (final missingCustomer in [true, false]) {
      expect(
        () => fromFeatureConsumptionResult(
          PFeatureConsumptionResult(
            operationId: 'incomplete',
            customerId: missingCustomer ? null : 'customer',
            featureId: missingCustomer ? 'credits' : null,
            accepted: true,
            code: 'consumed',
            quantity: 1,
            unlimited: false,
            active: false,
            idempotentReplay: false,
          ),
        ),
        throwsA(isA<NuxieException>()),
      );
    }
  });
  test('malformed snapshot cannot masquerade as denied ready state', () {
    expect(
      () => fromFeatureSnapshot(
        PFeatureSnapshot(
          session: 's',
          revision: 1,
          identityGeneration: 0,
          state: 'ready',
          all: {'credits': PFeatureAccess(type: 'metered')},
        ),
      ),
      throwsA(isA<NuxieException>()),
    );
  });
  test('checkout context retains exact plan and eligibility token', () {
    final product = fromPurchaseRequest(
      PPurchaseRequest(
        requestId: 'internal',
        platform: 'ios',
        productId: 'nuxie-product',
        storeProductId: 'store-product',
        timestampMs: 1,
        billingPlan: 'upFront',
        eligibilityJws: 'opaque-test-token',
        placementId: 'placement',
        introductoryTerms: PIntroductoryTerms(
          price: 'Free',
          period: 'week',
          periodCount: 1,
          cycles: 2,
          paymentMode: 'freeTrial',
          displayDuration: '2 weeks',
        ),
      ),
    ).product;
    expect(product.eligibilityJws, 'opaque-test-token');
    expect(product.billingPlan, 'upFront');
    expect(product.introductoryTerms?.cycles, 2);
    expect(product.placementId, 'placement');
  });
}
