import json

from django.core.exceptions import RequestDataTooBig, ValidationError
from django.http import JsonResponse
from django.db.models import Count, Exists, OuterRef, Value, BooleanField, Q
from django.utils import timezone

from accounts.authentication import get_session

from .models import Event, EventRegistration
from .services import EventAlreadyExists, RegistrationUnavailable, create_event, register_participant, cancel_participation

REQUIRED_FIELDS = (
    'baiguullagiindugaar', 'angilaliindugaar', 'garchig', 'bairshil',
    'ehleh_ognoo', 'duusah_ognoo', 'oroltsohchdiin_too',
)
OPTIONAL_FIELDS = ('argahemjeeniidugaar', 'tulwiindugaar', 'tailbar')


def event_data(event, user=None):
    data = {field: getattr(event, event._meta.get_field(field).attname)
            for field in REQUIRED_FIELDS + OPTIONAL_FIELDS}
    data['participant_count'] = getattr(event, 'participant_count', None)
    if data['participant_count'] is None:
        data['participant_count'] = event.registrations.filter(status_id='registered').count()
    data['is_joined'] = getattr(event, 'is_joined', None)
    if data['is_joined'] is None:
        data['is_joined'] = bool(user and event.registrations.filter(user=user, status_id='registered').exists())
    return data


def event_query(request):
    token = get_session(request)
    joined = Exists(EventRegistration.objects.filter(event=OuterRef('pk'), user=token.user, status_id='registered')) if token else Value(False, output_field=BooleanField())
    return Event.objects.annotate(participant_count=Count('registrations', filter=Q(registrations__status_id='registered')), is_joined=joined)


def create(request):
    if request.method != 'POST':
        response = JsonResponse({'message': 'POST хүсэлт илгээнэ үү.'}, status=405)
        response['Allow'] = 'POST'
        return response
    token = get_session(request)
    if token is None:
        return JsonResponse({'message': 'Имэйлээ баталгаажуулсан бүртгэлээр нэвтэрнэ үү.'}, status=401)
    if request.content_type != 'application/json':
        return JsonResponse({'message': 'application/json төрлөөр мэдээллээ илгээнэ үү.'}, status=415)
    try:
        body = json.loads(request.body)
    except RequestDataTooBig:
        return JsonResponse({'message': 'Хүсэлтийн хэмжээ хэтэрсэн байна.'}, status=413)
    except (ValueError, UnicodeDecodeError):
        return JsonResponse({'message': 'Зөв JSON хүсэлт илгээнэ үү.'}, status=400)
    if not isinstance(body, dict):
        return JsonResponse({'message': 'JSON object илгээнэ үү.'}, status=400)
    unknown = set(body) - set(REQUIRED_FIELDS + OPTIONAL_FIELDS)
    if unknown:
        return JsonResponse({'message': 'Танигдахгүй талбар байна.',
                             'errors': {field: ['Танигдахгүй талбар.'] for field in sorted(unknown)}}, status=400)
    values = {field: body.get(field) for field in REQUIRED_FIELDS}
    values.update({field: body[field] for field in OPTIONAL_FIELDS if field in body})
    try:
        event = create_event(**values, owner=token.user)
    except EventAlreadyExists as exc:
        return JsonResponse({'message': 'Үйл ажиллагааны дугаар давхардсан байна.', 'errors': exc.message_dict}, status=409)
    except ValidationError as exc:
        return JsonResponse({'message': 'Мэдээллээ шалгана уу.', 'errors': exc.message_dict}, status=400)
    return JsonResponse({'message': 'Үйл ажиллагаа амжилттай үүсгэлээ.', 'event': event_data(event)}, status=201)


def event_home(request):
    if request.method != 'GET':
        response = JsonResponse({'message': 'GET хүсэлт илгээнэ үү.'}, status=405)
        response['Allow'] = 'GET'
        return response
    try:
        limit, offset = int(request.GET.get('limit', '20')), int(request.GET.get('offset', '0'))
        if not 1 <= limit <= 100 or not 0 <= offset <= 2147483647:
            raise ValueError
    except ValueError:
        return JsonResponse({'message': 'limit 1–100, offset 0–2147483647 байна.'}, status=400)
    events = event_query(request)
    query = request.GET.get('q', '').strip()
    category = request.GET.get('category', '').strip()
    if query:
        events = events.filter(Q(garchig__icontains=query) | Q(bairshil__icontains=query))
    if category:
        events = events.filter(angilaliindugaar=category)
    if request.GET.get('upcoming') == 'true':
        events = events.filter(duusah_ognoo__gt=timezone.now())
    count = events.count()
    rows = list(events.order_by('ehleh_ognoo', 'pk')[offset:offset + limit])
    return JsonResponse({'events': [event_data(event) for event in rows], 'count': count,
                         'next_offset': offset + limit if offset + limit < count else None})


def detail(request, event_id):
    if request.method != 'GET':
        response = JsonResponse({'message': 'GET хүсэлт илгээнэ үү.'}, status=405)
        response['Allow'] = 'GET'
        return response
    event = event_query(request).filter(pk=event_id).first()
    return JsonResponse({'event': event_data(event)}) if event else JsonResponse({'message': 'Үйл ажиллагаа олдсонгүй.'}, status=404)


def participation(request, event_id, cancel=False):
    if request.method != 'POST':
        response = JsonResponse({'message': 'POST хүсэлт илгээнэ үү.'}, status=405)
        response['Allow'] = 'POST'
        return response
    token = get_session(request)
    if token is None:
        return JsonResponse({'message': 'Дахин нэвтэрнэ үү.'}, status=401)
    try:
        action = cancel_participation if cancel else register_participant
        event = action(event_id=event_id, user=token.user)
    except Event.DoesNotExist:
        return JsonResponse({'message': 'Үйл ажиллагаа олдсонгүй.'}, status=404)
    except RegistrationUnavailable as exc:
        return JsonResponse({'message': str(exc)}, status=409)
    return JsonResponse({'event': event_data(event, token.user)})
