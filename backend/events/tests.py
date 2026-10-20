from datetime import timedelta

from django.core.exceptions import ValidationError
from django.test import TestCase
from django.utils import timezone

from .models import Event
from .services import create_event


class EventCreationTests(TestCase):
    def setUp(self):
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
        event = Event.objects.get(pk=result['argahemjeeniidugaar'])
        self.assertEqual(event.baiguullagiindugaar, 'org-1')
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
