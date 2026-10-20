"""Resolve the explicit bearer session shared by protected API views."""
from django.utils import timezone

from .models import AuthToken
from .services import token_digest


def get_session(request):
    header = request.headers.get('Authorization', '')
    if not header.startswith('Bearer ') or not header[7:]:
        return None
    return AuthToken.objects.select_related('user').filter(
        digest=token_digest(header[7:]), expires_at__gt=timezone.now(),
        user__is_active=True, user__email_verified=True,
    ).first()
