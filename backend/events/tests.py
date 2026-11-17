from datetime import datetime, timedelta, timezone as dt_timezone
import json

from django.core.exceptions import ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone

from .models import CommentLike, Event, EventComment, Organization
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


class CommentTestBase(TestCase):
    """Сэтгэгдлийн тестүүдийн нийтлэг бэлтгэл (өөрөө тест агуулахгүй)."""

    def setUp(self):
        self.author = User.objects.create_user(
            username='commenter', email='commenter@example.com',
            password='Password123', name='Болд', email_verified=True)
        self.other = User.objects.create_user(
            username='other', email='other@example.com',
            password='Password123', name='Сараа', email_verified=True)
        self.organization = Organization.objects.create(
            id='org-c', name='Тест байгууллага', owner=self.author)
        start = timezone.now() + timedelta(days=1)
        self.event = create_event(
            argahemjeeniidugaar='event-c', baiguullagiindugaar='org-c',
            angilaliindugaar='environment', tulwiindugaar='open',
            garchig='Мод тарих', bairshil='Улаанбаатар',
            ehleh_ognoo=start, duusah_ognoo=start + timedelta(hours=2),
            oroltsohchdiin_too=5, owner=self.author)
        self.token = create_session(self.author)
        self.other_token = create_session(self.other)

    def _auth(self, token):
        return {'HTTP_AUTHORIZATION': f'Bearer {token}'}

    def _post(self, content, token=None, **extra):
        headers = self._auth(token) if token else {}
        headers.update(extra)
        return self.client.post(
            f'/events/{self.event.pk}/comments',
            data=json.dumps({'content': content}),
            content_type='application/json', **headers)


class EventCommentApiTests(CommentTestBase):
    """ШИНЭ: Сэтгэгдлийн үндсэн API."""

    def test_guest_can_read_but_not_write(self):
        self.assertEqual(self.client.get(f'/events/{self.event.pk}/comments').status_code, 200)
        self.assertEqual(self._post('Сайхан санаа').status_code, 401)

    def test_signed_in_user_can_post_and_read_back(self):
        response = self._post('Маш сайхан санаачилга!', self.token)
        self.assertEqual(response.status_code, 201)
        comment = response.json()['comment']
        self.assertEqual(comment['content'], 'Маш сайхан санаачилга!')
        self.assertEqual(comment['author_name'], 'Болд')
        self.assertTrue(comment['is_mine'])

        listing = self.client.get(f'/events/{self.event.pk}/comments', **self._auth(self.token)).json()
        self.assertEqual(listing['count'], 1)
        self.assertEqual(listing['comments'][0]['id'], comment['id'])
        self.assertTrue(listing['comments'][0]['is_mine'])

        # Өөр хэрэглэгчид is_mine=False байна.
        other_view = self.client.get(f'/events/{self.event.pk}/comments', **self._auth(self.other_token)).json()
        self.assertFalse(other_view['comments'][0]['is_mine'])

    def test_blank_and_too_long_comments_are_rejected(self):
        self.assertEqual(self._post('   ', self.token).status_code, 400)
        self.assertEqual(self._post('ө' * 1001, self.token).status_code, 400)
        self.assertEqual(EventComment.objects.count(), 0)

    def test_newest_comment_comes_first(self):
        self._post('Эхний', self.token)
        self._post('Хоёр дахь', self.other_token)
        rows = self.client.get(f'/events/{self.event.pk}/comments').json()['comments']
        self.assertEqual([row['content'] for row in rows], ['Хоёр дахь', 'Эхний'])

    def test_missing_event_returns_404(self):
        self.assertEqual(self.client.get('/events/does-not-exist/comments').status_code, 404)

    def test_author_can_delete_own_comment_but_stranger_cannot(self):
        comment_id = self._post('Устгах сэтгэгдэл', self.other_token).json()['comment']['id']
        url = f'/events/{self.event.pk}/comments/{comment_id}/delete'

        third = User.objects.create_user(
            username='third', email='third@example.com',
            password='Password123', name='Гурав', email_verified=True)
        third_token = create_session(third)
        self.assertEqual(self.client.post(url, **self._auth(third_token)).status_code, 403)
        self.assertEqual(EventComment.objects.count(), 1)

        self.assertEqual(self.client.post(url, **self._auth(self.other_token)).status_code, 200)
        self.assertEqual(EventComment.objects.count(), 0)

    def test_event_owner_can_moderate_any_comment(self):
        comment_id = self._post('Зохисгүй сэтгэгдэл', self.other_token).json()['comment']['id']
        url = f'/events/{self.event.pk}/comments/{comment_id}/delete'
        self.assertEqual(self.client.post(url, **self._auth(self.token)).status_code, 200)
        self.assertEqual(EventComment.objects.count(), 0)

    def test_deleting_event_removes_its_comments(self):
        self._post('Үлдэх ёсгүй', self.token)
        self.event.delete()
        self.assertEqual(EventComment.objects.count(), 0)


class EventCommentExtrasTests(CommentTestBase):
    """ШИНЭ: зураг, таалагдсан (like), хариу (reply)."""

    def _post_raw(self, body, token=None):
        headers = self._auth(token) if token else {}
        return self.client.post(
            f'/events/{self.event.pk}/comments',
            data=json.dumps(body), content_type='application/json', **headers)

    def test_comment_may_carry_only_an_image(self):
        image = f'http://testserver/media/events/{"a" * 8}.jpg'
        response = self._post_raw({'content': '', 'zurag': image}, self.token)
        self.assertEqual(response.status_code, 201)
        comment = response.json()['comment']
        self.assertEqual(comment['zurag'], image)
        self.assertEqual(comment['content'], '')

    def test_foreign_image_urls_are_rejected(self):
        response = self._post_raw(
            {'content': 'Зурагтай', 'zurag': 'https://evil.example.com/a.jpg'}, self.token)
        self.assertEqual(response.status_code, 400)
        self.assertEqual(EventComment.objects.count(), 0)

    def test_unknown_fields_are_rejected(self):
        response = self._post_raw({'content': 'Сайн', 'hello': 1}, self.token)
        self.assertEqual(response.status_code, 400)

    def test_like_toggles_and_counts_once_per_user(self):
        comment_id = self._post('Таалагдах сэтгэгдэл', self.token).json()['comment']['id']
        url = f'/events/{self.event.pk}/comments/{comment_id}/like'

        first = self.client.post(url, **self._auth(self.other_token)).json()['comment']
        self.assertEqual(first['like_count'], 1)
        self.assertTrue(first['liked_by_me'])

        # Дахин дарвал буцаана.
        second = self.client.post(url, **self._auth(self.other_token)).json()['comment']
        self.assertEqual(second['like_count'], 0)
        self.assertFalse(second['liked_by_me'])

        self.client.post(url, **self._auth(self.other_token))
        self.client.post(url, **self._auth(self.token))
        self.assertEqual(CommentLike.objects.filter(comment_id=comment_id).count(), 2)

        # Нэвтрээгүй хүн дарж чадахгүй.
        self.assertEqual(self.client.post(url).status_code, 401)

    def test_guest_listing_shows_counts_but_not_liked_by_me(self):
        comment_id = self._post('Тоолъё', self.token).json()['comment']['id']
        self.client.post(
            f'/events/{self.event.pk}/comments/{comment_id}/like', **self._auth(self.other_token))
        row = self.client.get(f'/events/{self.event.pk}/comments').json()['comments'][0]
        self.assertEqual(row['like_count'], 1)
        self.assertFalse(row['liked_by_me'])

    def test_reply_is_nested_under_its_parent(self):
        parent_id = self._post('Үндсэн сэтгэгдэл', self.token).json()['comment']['id']
        reply = self._post_raw(
            {'content': 'Хариу', 'parent': parent_id}, self.other_token).json()['comment']
        self.assertEqual(reply['parent_id'], parent_id)

        listing = self.client.get(f'/events/{self.event.pk}/comments').json()
        self.assertEqual(len(listing['comments']), 1, 'хариу тусдаа мөр болж харагдах ёсгүй')
        self.assertEqual(listing['count'], 2)
        self.assertEqual(listing['comments'][0]['replies'][0]['content'], 'Хариу')

    def test_reply_to_a_reply_attaches_to_the_root_comment(self):
        parent_id = self._post('Үндсэн', self.token).json()['comment']['id']
        reply_id = self._post_raw(
            {'content': 'Хариу 1', 'parent': parent_id}, self.other_token).json()['comment']['id']
        deep = self._post_raw(
            {'content': 'Хариу 2', 'parent': reply_id}, self.token).json()['comment']
        self.assertEqual(deep['parent_id'], parent_id)

        listing = self.client.get(f'/events/{self.event.pk}/comments').json()
        self.assertEqual(len(listing['comments'][0]['replies']), 2)

    def test_reply_to_an_unknown_comment_returns_404(self):
        self.assertEqual(self._post_raw({'content': 'Хариу', 'parent': 999}, self.token).status_code, 404)

    def test_deleting_a_parent_removes_its_replies(self):
        parent_id = self._post('Үндсэн', self.token).json()['comment']['id']
        self._post_raw({'content': 'Хариу', 'parent': parent_id}, self.other_token)
        self.assertEqual(EventComment.objects.count(), 2)

        self.client.post(
            f'/events/{self.event.pk}/comments/{parent_id}/delete', **self._auth(self.token))
        self.assertEqual(EventComment.objects.count(), 0)

    def test_deleting_a_comment_removes_its_likes(self):
        comment_id = self._post('Устгана', self.token).json()['comment']['id']
        self.client.post(
            f'/events/{self.event.pk}/comments/{comment_id}/like', **self._auth(self.other_token))
        self.assertEqual(CommentLike.objects.count(), 1)

        self.client.post(
            f'/events/{self.event.pk}/comments/{comment_id}/delete', **self._auth(self.token))
        self.assertEqual(CommentLike.objects.count(), 0)


class EventDateFilterTests(TestCase):
    """ШИНЭ: жагсаалтыг он / сараар шүүх."""

    def setUp(self):
        self.owner = User.objects.create_user(
            username='lister', email='lister@example.com',
            password='Password123', name='Лист', email_verified=True)
        Organization.objects.create(id='org-d', name='Огноо ТББ', owner=self.owner)
        self.dates = {
            'event-mar': datetime(2027, 3, 10, 9, tzinfo=dt_timezone.utc),
            'event-may': datetime(2027, 5, 10, 9, tzinfo=dt_timezone.utc),
            'event-old': datetime(2026, 5, 10, 9, tzinfo=dt_timezone.utc),
        }
        for event_id, start in self.dates.items():
            create_event(
                argahemjeeniidugaar=event_id, baiguullagiindugaar='org-d',
                angilaliindugaar='environment', tulwiindugaar='open',
                garchig=event_id, bairshil='Улаанбаатар',
                ehleh_ognoo=start, duusah_ognoo=start + timedelta(hours=3),
                oroltsohchdiin_too=5, owner=self.owner)

    def ids(self, query):
        rows = self.client.get('/events/' + query).json()['events']
        return sorted(row['argahemjeeniidugaar'] for row in rows)

    def test_filter_by_year(self):
        self.assertEqual(self.ids('?year=2027'), ['event-mar', 'event-may'])
        self.assertEqual(self.ids('?year=2026'), ['event-old'])

    def test_filter_by_month(self):
        self.assertEqual(self.ids('?month=5'), ['event-may', 'event-old'])

    def test_year_and_month_combine(self):
        self.assertEqual(self.ids('?year=2027&month=5'), ['event-may'])

    def test_empty_values_are_ignored(self):
        self.assertEqual(len(self.ids('?year=&month=')), 3)

    def test_invalid_values_are_rejected(self):
        for query in ('?year=abc', '?month=0', '?month=13', '?year=1800'):
            with self.subTest(query=query):
                self.assertEqual(self.client.get('/events/' + query).status_code, 400)

    def test_date_filter_combines_with_search(self):
        self.assertEqual(self.ids('?year=2027&q=event-mar'), ['event-mar'])
