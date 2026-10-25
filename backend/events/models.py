from uuid import uuid4
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


def organization_id():
    return str(uuid4())


class Organization(models.Model):
    id = models.CharField(max_length=50, primary_key=True, default=organization_id)
    # Historical rows did not record ownership; do not guess their owner.
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                              related_name='organizations', null=True, blank=True)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    contact_email = models.EmailField(blank=True)
    is_verified = models.BooleanField(default=False)

    def __str__(self):
        return self.name


class Category(models.Model):
    id = models.CharField(max_length=50, primary_key=True)
    name = models.CharField(max_length=100)


class EventStatus(models.Model):
    id = models.CharField(max_length=50, primary_key=True)
    name = models.CharField(max_length=100)


class RegistrationStatus(models.Model):
    id = models.CharField(max_length=50, primary_key=True)
    name = models.CharField(max_length=100)


class Event(models.Model):
    argahemjeeniidugaar = models.CharField(max_length=50, primary_key=True, verbose_name='Арга хэмжээний дугаар')
    baiguullagiindugaar = models.ForeignKey(Organization, db_column='baiguullagiindugaar',
        on_delete=models.PROTECT, related_name='events', verbose_name='Байгууллага')
    angilaliindugaar = models.ForeignKey(Category, db_column='angilaliindugaar',
        on_delete=models.PROTECT, related_name='events', verbose_name='Ангилал')
    tulwiindugaar = models.ForeignKey(EventStatus, db_column='tulwiindugaar', default='open',
        on_delete=models.PROTECT, related_name='events', verbose_name='Төлөв')
    garchig = models.CharField(max_length=200, verbose_name='Гарчиг')
    tailbar = models.TextField(blank=True, verbose_name='Тайлбар')
    bairshil = models.CharField(max_length=300, verbose_name='Байршил')
    ehleh_ognoo = models.DateTimeField(verbose_name='Эхлэх огноо')
    duusah_ognoo = models.DateTimeField(verbose_name='Дуусах огноо')
    oroltsohchdiin_too = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(2147483647)], verbose_name='Оролцогчдын тоо')
    # ШИНЭ: зургийн URL. Хуучин эвентүүд хоосон ('') утгатай үлдэнэ.
    zurag = models.CharField(max_length=500, blank=True, default='', verbose_name='Зураг')

    def clean(self):
        super().clean()
        if self.ehleh_ognoo and self.duusah_ognoo and self.duusah_ognoo <= self.ehleh_ognoo:
            raise ValidationError({'duusah_ognoo': 'Дуусах огноо эхлэх огнооноос хойш байна.'})

    def __str__(self):
        return self.garchig

    class Meta:
        db_table = 'argahemjee'
        verbose_name = 'Арга хэмжээ'
        verbose_name_plural = 'Арга хэмжээнүүд'
        indexes = [models.Index(fields=['ehleh_ognoo', 'argahemjeeniidugaar'], name='event_start_id_idx')]
        constraints = [
            models.CheckConstraint(condition=models.Q(duusah_ognoo__gt=models.F('ehleh_ognoo')), name='event_end_after_start'),
            models.CheckConstraint(condition=models.Q(oroltsohchdiin_too__gte=1, oroltsohchdiin_too__lte=2147483647), name='event_capacity_range'),
        ]


class EventRegistration(models.Model):
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='registrations')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='event_registrations')
    status = models.ForeignKey(RegistrationStatus, on_delete=models.PROTECT, default='registered')
    attended = models.BooleanField(default=False)
    worked_hours = models.DecimalField(max_digits=7, decimal_places=2, default=0, validators=[MinValueValidator(0)])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['event', 'user'], name='unique_event_registration'),
            models.CheckConstraint(condition=models.Q(worked_hours__gte=0), name='registration_hours_nonnegative'),
        ]


class Review(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='event_reviews')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='reviews')
    score = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['event', 'user'], name='unique_event_review'),
            models.CheckConstraint(condition=models.Q(score__gte=1, score__lte=5), name='review_score_range'),
        ]


class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    content = models.TextField()
    is_read = models.BooleanField(default=False)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['user', 'is_read', '-sent_at'], name='notification_inbox_idx')]