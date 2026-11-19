import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';

class AuthenticatedTestSession extends SessionController {
  @override
  SessionState build() => const SessionState(
        phase: SessionPhase.authenticated,
        user: AuthUser(id: 7, name: 'Operator', email: 'operator@example.test'),
        organizations: [
          OrganizationAccess(
              id: 'north', name: 'North', role: 'viewer', permissions: [])
        ],
        organization: OrganizationAccess(
            id: 'north', name: 'North', role: 'viewer', permissions: []),
      );

  @override
  Future<void> restore() async {}
}
