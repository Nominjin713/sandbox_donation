from datetime import timedelta
import json

from django.core.exceptions import ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone

from .models import Event, Organization
from .services import create_event
from accounts.models import AuthToken, User
from accounts.services import create_session


class EventCreationTests(TestCase):
    def setUp(self):
        Organization.objects.create(id='org-1', name='Тест байгууллага')
        start = timezone.now() + timedelta(days=1)
        self.data = {
            'argahemjeeniidugaar': 'event-1', 'baiguullagiindugaar': 'org-1',
            'angilaliindugaar': 'environment', 'tulwiindugaar': 'open',
            'garchig': ' Мод тарих ', 'bairshil': ' Улаанбаатар ',
            'ehleh_ognoo': start, 'duusah_ognoo': start + timedelta(hours=2),
            'oroltsohchdiin_too': 5,
        }

    def test_create_stores_required_fields_and_correct_organization_column(self):
        result = create_event(**self.data)
        event = Event.objects.get(pk=result.pk)
        self.assertEqual(event.baiguullagiindugaar_id, 'org-1')
        self.assertEqual(event.garchig, 'Мод тарих')
        self.assertEqual(event.bairshil, 'Улаанбаатар')
        self.assertEqual(event.ehleh_ognoo, self.data['ehleh_ognoo'])
        self.assertEqual(event.oroltsohchdiin_too, 5)

    def test_invalid_data_is_rejected_without_inserting(self):
        for changes in ({'duusah_ognoo': self.data['ehleh_ognoo']},
                        {'garchig': ' '}, {'baiguullagiindugaar': ''},
                        {'oroltsohchdiin_too': -1}, {'ehleh_ognoo': None}):
            with self.subTest(changes=changes):
                with self.assertRaises(ValidationError):
                    create_event(**{**self.data, **changes})
                self.assertEqual(Event.objects.count(), 0)

    def test_duplicate_id_does_not_replace_an_existing_event(self):
        create_event(**self.data)
        with self.assertRaises(ValidationError):
            create_event(**{**self.data, 'garchig': 'Replacement'})
        self.assertEqual(Event.objects.get().garchig, 'Мод тарих')

    def test_ids_and_status_are_generated_when_omitted(self):
        data = {key: value for key, value in self.data.items()
                if key not in ('argahemjeeniidugaar', 'tulwiindugaar')}
        first = create_event(**data)
        second = create_event(**data)
        self.assertNotEqual(first.pk, second.pk)
        self.assertEqual(first.tulwiindugaar_id, 'open')
        self.assertEqual(Event.objects.count(), 2)

    def test_invalid_types_and_integer_boundaries_do_not_reach_database(self):
        for changes in ({'garchig': 123}, {'tailbar': None}, {'oroltsohchdiin_too': True},
                        {'oroltsohchdiin_too': 0}, {'oroltsohchdiin_too': '5'},
                        {'oroltsohchdiin_too': 1.5}, {'oroltsohchdiin_too': 2147483648},
                        {'ehleh_ognoo': 'not-a-date'}, {'ehleh_ognoo': '2030-02-31T10:00:00+08:00'},
                        {'ehleh_ognoo': '2030-10-20T10:00:00'}, {'garchig': 'a' * 201}):
            with self.subTest(changes=changes):
                with self.assertRaises(ValidationError):
                    create_event(**{**self.data, **changes})
                self.assertEqual(Event.objects.count(), 0)


class EventApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='organizer', email='organizer@example.com',
                                             name='Болд', email_verified=True)
        self.token = create_session(self.user)
        self.headers = {'HTTP_AUTHORIZATION': 'Bearer ' + self.token}
        self.data = {
            'baiguullagiindugaar': 'org-1', 'angilaliindugaar': 'environment',
            'garchig': ' Мод тарих ', 'bairshil': ' Улаанбаатар ', 'tailbar': 'Хамтдаа мод тарина.',
            'ehleh_ognoo': '2030-10-20T10:00:00+08:00',
            'duusah_ognoo': '2030-10-20T12:00:00+08:00', 'oroltsohchdiin_too': 10,
        }

    def post(self, data, *, headers=None):
        return self.client.post('/events/create', json.dumps(data),
                                content_type='application/json',
                                **(self.headers if headers is None else headers))

    def test_verified_user_creates_a_persisted_event(self):
        response = self.post(self.data)
        self.assertEqual(response.status_code, 201)
        body = response.json()['event']
        event = Event.objects.get(pk=body['argahemjeeniidugaar'])
        self.assertEqual(body['garchig'], 'Мод тарих')
        self.assertEqual(body['tulwiindugaar'], 'open')
        self.assertEqual(event.baiguullagiindugaar_id, 'org-1')
        self.assertEqual(event.ehleh_ognoo.isoformat(), '2030-10-20T02:00:00+00:00')
        self.assertEqual(body['oroltsohchdiin_too'], 10)

    def test_requires_an_active_verified_session(self):
        self.assertEqual(self.post(self.data, headers={}).status_code, 401)
        self.assertEqual(self.post(self.data, headers={'HTTP_AUTHORIZATION': 'Bearer invalid'}).status_code, 401)
        self.user.email_verified = False
        self.user.save(update_fields=['email_verified'])
        self.assertEqual(self.post(self.data).status_code, 401)
        self.user.email_verified = True
        self.user.is_active = False
        self.user.save(update_fields=['email_verified', 'is_active'])
        self.assertEqual(self.post(self.data).status_code, 401)
        self.user.is_active = True
        self.user.save(update_fields=['is_active'])
        AuthToken.objects.filter(user=self.user).update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.post(self.data).status_code, 401)
        self.assertEqual(Event.objects.count(), 0)

    def test_duplicate_client_id_returns_conflict_and_preserves_original(self):
        data = {**self.data, 'argahemjeeniidugaar': 'client-event-1'}
        self.assertEqual(self.post(data).status_code, 201)
        response = self.post({**data, 'garchig': 'Replacement'})
        self.assertEqual(response.status_code, 409)
        self.assertIn('argahemjeeniidugaar', response.json()['errors'])
        self.assertEqual(Event.objects.get().garchig, 'Мод тарих')

    def test_bad_input_returns_field_errors_without_inserting(self):
        for changes, field in (({'oroltsohchdiin_too': True}, 'oroltsohchdiin_too'),
                               ({'duusah_ognoo': self.data['ehleh_ognoo']}, 'duusah_ognoo'),
                               ({'garchig': ' '}, 'garchig'), ({'unknown': 1}, 'unknown')):
            with self.subTest(changes=changes):
                response = self.post({**self.data, **changes})
                self.assertEqual(response.status_code, 400)
                self.assertIn(field, response.json()['errors'])
        response = self.post({})
        self.assertEqual(response.status_code, 400)
        self.assertIn('garchig', response.json()['errors'])
        self.assertEqual(Event.objects.count(), 0)

    def test_malformed_json_and_non_objects_are_rejected(self):
        for payload in (None, [], 'text', 1):
            self.assertEqual(self.post(payload).status_code, 400)
        for payload in (b'{', b'\xff'):
            response = self.client.post('/events/create', payload, content_type='application/json', **self.headers)
            self.assertEqual(response.status_code, 400)
        self.assertEqual(Event.objects.count(), 0)

    @override_settings(DATA_UPLOAD_MAX_MEMORY_SIZE=32)
    def test_oversized_body_returns_413(self):
        self.assertEqual(self.post(self.data).status_code, 413)
        self.assertEqual(Event.objects.count(), 0)

    def test_method_and_media_type_are_explicit(self):
        response = self.client.get('/events/create', **self.headers)
        self.assertEqual(response.status_code, 405)
        self.assertEqual(response['Allow'], 'POST')
        self.assertIn('message', response.json())
        response = self.client.post('/events/create', self.data, **self.headers)
        self.assertEqual(response.status_code, 415)

    def test_list_search_category_pagination_and_detail(self):
        first = self.post(self.data).json()['event']
        self.post({**self.data, 'garchig': 'Ном унших', 'angilaliindugaar': 'education'})
        page = self.client.get('/events/', {'limit': 1}).json()
        self.assertEqual(page['count'], 2)
        self.assertEqual(len(page['events']), 1)
        self.assertEqual(page['next_offset'], 1)
        second = self.client.get('/events/', {'limit': 1, 'offset': 1}).json()
        self.assertNotEqual(page['events'][0]['argahemjeeniidugaar'], second['events'][0]['argahemjeeniidugaar'])
        self.assertIsNone(second['next_offset'])
        self.assertEqual(self.client.get('/events/', {'q': 'Ном'}).json()['count'], 1)
        self.assertEqual(self.client.get('/events/', {'category': 'education'}).json()['count'], 1)
        detail = self.client.get(f"/events/{first['argahemjeeniidugaar']}/").json()['event']
        self.assertEqual(detail['garchig'], 'Мод тарих')
        self.assertEqual(detail['participant_count'], 0)

    def test_invalid_pagination_and_missing_events(self):
        for params in ({'limit': 'bad'}, {'limit': 0}, {'limit': 101}, {'offset': -1}, {'offset': 2 ** 64}):
            self.assertEqual(self.client.get('/events/', params).status_code, 400)
        self.assertEqual(self.client.get('/events/missing/').status_code, 404)
        self.assertEqual(self.client.post('/events/missing/join', **self.headers).status_code, 404)
        self.assertEqual(self.client.post('/events/missing/leave', **self.headers).status_code, 404)

    def test_join_is_idempotent_and_persisted_on_reload(self):
        event_id = self.post(self.data).json()['event']['argahemjeeniidugaar']
        route = f'/events/{event_id}/join'
        self.assertEqual(self.client.post(route).status_code, 401)
        self.assertEqual(self.client.get(route, **self.headers).status_code, 405)
        for _ in range(2):
            response = self.client.post(route, **self.headers)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['event']['participant_count'], 1)
        detail = self.client.get(f'/events/{event_id}/', **self.headers).json()['event']
        self.assertTrue(detail['is_joined'])
        public = self.client.get(f'/events/{event_id}/').json()['event']
        self.assertFalse(public['is_joined'])
        self.assertEqual(public['participant_count'], 1)
        self.assertNotIn('users', public)
        listing = self.client.get('/events/', **self.headers).json()['events'][0]
        self.assertTrue(listing['is_joined'])

    def test_capacity_and_cancel_allow_another_user_to_join(self):
        event_id = self.post({**self.data, 'oroltsohchdiin_too': 1}).json()['event']['argahemjeeniidugaar']
        other = User.objects.create_user(username='second', email='second@example.com', email_verified=True)
        other_headers = {'HTTP_AUTHORIZATION': 'Bearer ' + create_session(other)}
        join = f'/events/{event_id}/join'
        leave = f'/events/{event_id}/leave'
        self.assertEqual(self.client.post(join, **self.headers).status_code, 200)
        self.assertEqual(self.client.post(join, **other_headers).status_code, 409)
        self.assertEqual(Event.objects.get().registrations.count(), 1)
        self.client.post(leave, **other_headers)
        self.assertEqual(Event.objects.get().registrations.count(), 1)
        for _ in range(2):
            result = self.client.post(leave, **self.headers).json()['event']
            self.assertFalse(result['is_joined'])
            self.assertEqual(result['participant_count'], 0)
        self.assertEqual(self.client.post(join, **other_headers).status_code, 200)

    def test_closed_or_ended_event_rejects_new_registration(self):
        closed = self.post({**self.data, 'tulwiindugaar': 'closed'}).json()['event']['argahemjeeniidugaar']
        self.assertEqual(self.client.post(f'/events/{closed}/join', **self.headers).status_code, 409)
        end = timezone.now() - timedelta(days=1)
        past = self.post({**self.data, 'ehleh_ognoo': (end - timedelta(hours=1)).isoformat(), 'duusah_ognoo': end.isoformat()}).json()['event']['argahemjeeniidugaar']
        self.assertEqual(self.client.post(f'/events/{past}/join', **self.headers).status_code, 409)
        self.assertEqual(self.client.get('/events/', {'upcoming': 'true'}).json()['count'], 1)
