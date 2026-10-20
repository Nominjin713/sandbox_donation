"""Event creation rules, independent of HTTP and authentication transport."""
from datetime import datetime
from uuid import uuid4

from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from .models import Event, EventRegistration, Organization


class EventAlreadyExists(ValidationError):
    """The database rejected a duplicate event identifier."""


def event_datetime(value, field, errors):
    if isinstance(value, str):
        try:
            value = parse_datetime(value)
        except ValueError:
            value = None
    if not isinstance(value, datetime) or timezone.is_naive(value):
        errors[field] = ['Цагийн бүстэй ISO 8601 огноо оруулна уу.']
        return None
    return value


@transaction.atomic
def create_event(
    *, baiguullagiindugaar, angilaliindugaar, garchig, bairshil,
    ehleh_ognoo, duusah_ognoo, oroltsohchdiin_too,
    argahemjeeniidugaar=None, tulwiindugaar='open', tailbar='', owner=None,
):
    errors = {}
    values = {
        'argahemjeeniidugaar': str(uuid4()) if argahemjeeniidugaar is None else argahemjeeniidugaar,
        'baiguullagiindugaar': baiguullagiindugaar,
        'angilaliindugaar': angilaliindugaar,
        'tulwiindugaar': tulwiindugaar,
        'garchig': garchig, 'bairshil': bairshil, 'tailbar': tailbar,
    }
    for field, value in values.items():
        if not isinstance(value, str):
            errors[field] = ['Текст утга оруулна уу.']
        else:
            values[field] = value.strip()
    if type(oroltsohchdiin_too) is not int or not 1 <= oroltsohchdiin_too <= 2147483647:
        errors['oroltsohchdiin_too'] = ['Оролцогчдын тоо 1–2147483647 бүхэл тоо байна.']
    values['ehleh_ognoo'] = event_datetime(ehleh_ognoo, 'ehleh_ognoo', errors)
    values['duusah_ognoo'] = event_datetime(duusah_ognoo, 'duusah_ognoo', errors)
    if errors:
        raise ValidationError(errors)
    org_id = values['baiguullagiindugaar']
    if not org_id or len(org_id) > 50:
        raise ValidationError({'baiguullagiindugaar': ['Байгууллагын дугаар 1–50 тэмдэгт байна.']})
    if owner is not None:
        organization, _ = Organization.objects.get_or_create(
            pk=org_id, defaults={'name': org_id, 'owner': owner, 'contact_email': owner.email})
        if organization.owner_id != owner.pk:
            raise ValidationError({'baiguullagiindugaar': ['Зөвхөн өөрийн байгууллагаар нийтэлнэ үү.']})
    for field in ('baiguullagiindugaar', 'angilaliindugaar', 'tulwiindugaar'):
        values[field + '_id'] = values.pop(field)
    event = Event(**values, oroltsohchdiin_too=oroltsohchdiin_too)
    # The database handles uniqueness so concurrent requests cannot overwrite a row.
    event.full_clean(validate_unique=False)
    try:
        with transaction.atomic():
            event.save(force_insert=True)
    except IntegrityError:
        if Event.objects.filter(pk=event.pk).exists():
            raise EventAlreadyExists({
                'argahemjeeniidugaar': ['Энэ дугаартай үйл ажиллагаа бүртгэлтэй байна.'],
            }) from None
        raise
    return event


class RegistrationUnavailable(Exception):
    pass


@transaction.atomic
def register_participant(*, event_id, user):
    event = Event.objects.select_for_update().get(pk=event_id)
    registration = EventRegistration.objects.filter(event=event, user=user).first()
    if registration and registration.status_id == 'registered':
        return event
    if event.tulwiindugaar_id != 'open' or event.duusah_ognoo <= timezone.now():
        raise RegistrationUnavailable('Энэ үйл ажиллагааны бүртгэл хаагдсан байна.')
    if event.registrations.filter(status_id='registered').count() >= event.oroltsohchdiin_too:
        raise RegistrationUnavailable('Оролцогчдын бүртгэл дүүрсэн байна.')
    if registration:
        registration.status_id = 'registered'
        registration.save(update_fields=['status'])
    else:
        EventRegistration.objects.create(event=event, user=user)
    return event


@transaction.atomic
def cancel_participation(*, event_id, user):
    event = Event.objects.select_for_update().get(pk=event_id)
    EventRegistration.objects.filter(event=event, user=user).update(status_id='cancelled')
    return event
