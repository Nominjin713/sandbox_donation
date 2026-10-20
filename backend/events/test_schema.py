from datetime import timedelta
from decimal import Decimal

from django.db import IntegrityError, connection, transaction
from django.db.migrations.executor import MigrationExecutor
from django.db.models.deletion import ProtectedError
from django.test import TestCase, TransactionTestCase
from django.utils import timezone
from django.core.exceptions import ValidationError

from accounts.models import User
from .models import Category, Event, EventRegistration, Organization, Review
from .services import cancel_participation, create_event, register_participant


class SchemaTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='schema', email='schema@example.com')
        self.organization = Organization.objects.create(id='org', name='Байгууллага', owner=self.user)
        start = timezone.now() + timedelta(days=1)
        self.data = dict(baiguullagiindugaar='org', angilaliindugaar='environment',
                         garchig='Арга хэмжээ', bairshil='Улаанбаатар',
                         ehleh_ognoo=start, duusah_ognoo=start + timedelta(hours=1),
                         oroltsohchdiin_too=5)
        self.event = create_event(**self.data)

    def test_referenced_organization_category_cannot_be_deleted(self):
        for obj in (self.organization, Category.objects.get(pk='environment'), self.user):
            with self.assertRaises(ProtectedError):
                obj.delete()

    def test_database_rejects_invalid_dates_and_capacity_without_service(self):
        for changes in ({'duusah_ognoo': self.event.ehleh_ognoo}, {'oroltsohchdiin_too': 0}):
            with self.assertRaises(IntegrityError), transaction.atomic():
                Event.objects.filter(pk=self.event.pk).update(**changes)

    def test_cancel_preserves_hours_and_rejoin_reuses_registration(self):
        register_participant(event_id=self.event.pk, user=self.user)
        registration = EventRegistration.objects.get(event=self.event, user=self.user)
        registration.worked_hours = Decimal('2.50')
        registration.attended = True
        registration.save()
        cancel_participation(event_id=self.event.pk, user=self.user)
        registration.refresh_from_db()
        self.assertEqual(registration.status_id, 'cancelled')
        self.assertEqual(registration.worked_hours, Decimal('2.50'))
        register_participant(event_id=self.event.pk, user=self.user)
        registration.refresh_from_db()
        self.assertEqual(registration.status_id, 'registered')
        self.assertEqual(EventRegistration.objects.count(), 1)

    def test_database_rejects_negative_hours_duplicate_registration_and_review(self):
        registration = EventRegistration.objects.create(event=self.event, user=self.user)
        with self.assertRaises(IntegrityError), transaction.atomic():
            EventRegistration.objects.filter(pk=registration.pk).update(worked_hours=-1)
        with self.assertRaises(IntegrityError), transaction.atomic():
            EventRegistration.objects.create(event=self.event, user=self.user)
        for score in (0, 6):
            with self.assertRaises(IntegrityError), transaction.atomic():
                Review.objects.create(event=self.event, user=self.user, score=score)
        Review.objects.create(event=self.event, user=self.user, score=5)
        with self.assertRaises(IntegrityError), transaction.atomic():
            Review.objects.create(event=self.event, user=self.user, score=4)

    def test_creation_cannot_impersonate_another_organization(self):
        other = User.objects.create_user(username='other-schema', email='other-schema@example.com')
        with self.assertRaises(ValidationError):
            create_event(**self.data, owner=other)
        self.assertEqual(Event.objects.count(), 1)

    def test_bad_reference_rolls_back_new_organization(self):
        with self.assertRaises(ValidationError):
            create_event(**{**self.data, 'baiguullagiindugaar': 'new-org',
                            'angilaliindugaar': 'missing-category'}, owner=self.user)
        self.assertFalse(Organization.objects.filter(pk='new-org').exists())


class HistoricalMigrationTests(TransactionTestCase):
    def test_text_references_and_registrations_survive_normalization(self):
        before = [('events', '0002_eventregistration')]
        after = [('events', '0003_category_eventstatus_registrationstatus_review_and_more')]
        executor = MigrationExecutor(connection)
        executor.migrate(before)
        old = executor.loader.project_state(before).apps
        try:
            user = User.objects.create(
                username='legacy', name='Legacy', email='legacy@example.com')
            start = timezone.now()
            old.get_model('events', 'Event').objects.create(
                argahemjeeniidugaar='legacy-event', baiguullagiindugaar='legacy-org',
                angilaliindugaar='legacy-category', tulwiindugaar='legacy-status',
                garchig='Historical event', bairshil='UB', ehleh_ognoo=start,
                duusah_ognoo=start + timedelta(hours=1), oroltsohchdiin_too=10)
            old.get_model('events', 'EventRegistration').objects.create(event_id='legacy-event', user_id=user.pk)
            executor = MigrationExecutor(connection)
            executor.migrate(after)
            event = Event.objects.get(pk='legacy-event')
            self.assertEqual(event.baiguullagiindugaar.name, 'legacy-org')
            self.assertIsNone(event.baiguullagiindugaar.owner_id)
            self.assertEqual(event.angilaliindugaar_id, 'legacy-category')
            self.assertEqual(event.tulwiindugaar_id, 'legacy-status')
            self.assertEqual(event.registrations.get().status_id, 'registered')
            connection.check_constraints()
        finally:
            MigrationExecutor(connection).migrate(after)
