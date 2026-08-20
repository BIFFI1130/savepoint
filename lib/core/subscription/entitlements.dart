/// RevenueCatダッシュボード側で定義するEntitlement識別子。
///
/// 「どの購入がどの機能を解放するか」はRevenueCat側が真実の情報源であり、
/// Dart側は識別子の受け皿を持つだけにする。新しい課金機能を追加する時は、
/// ダッシュボードでEntitlementを作成し、ここに定数を1つ足すだけでよい。
///
/// 注意: 値はRevenueCatダッシュボードのEntitlement名と完全一致させる必要がある
/// （コンパイル時のチェックは効かないため、命名ミスに注意）。
class Entitlements {
  const Entitlements._();

  static const adFree = 'ad_free';
}
