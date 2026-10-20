
from django.db import models
from django.core.exceptions import ValidationError


class Event(models.Model):
    argahemjeeniidugaar = models.CharField(
        max_length=50,
        primary_key=True,
        verbose_name="Арга хэмжээний дугаар",
    )

    baiguullagiindugaar = models.CharField(
        max_length=50,
        verbose_name="Байгууллагын дугаар",
    )

    angilaliindugaar = models.CharField(
        max_length=50,
        verbose_name="Ангиллын дугаар",
    )

    tulwiindugaar = models.CharField(
        max_length=50,
        verbose_name="Төлөвийн дугаар",
    )

    garchig = models.CharField(
        max_length=200,
        verbose_name="Гарчиг",
    )

    tailbar = models.TextField(
        blank=True,
        verbose_name="Тайлбар",
    )

    bairshil = models.CharField(
        max_length=300,
        verbose_name="Байршил",
    )

    ehleh_ognoo = models.DateTimeField(
        verbose_name="Эхлэх огноо",
    )

    duusah_ognoo = models.DateTimeField(
        verbose_name="Дуусах огноо",
    )

    oroltsohchdiin_too = models.PositiveIntegerField(
        verbose_name="Оролцогчдын тоо",
    )

    def clean(self):
        super().clean()

        if (
            self.ehleh_ognoo
            and self.duusah_ognoo
            and self.duusah_ognoo <= self.ehleh_ognoo
        ):
            raise ValidationError({
                "duusah_ognoo":
                    "Дуусах огноо эхлэх огнооноос хойш байх ёстой."
            })

    def __str__(self):
        return self.garchig

    class Meta:
        db_table = "argahemjee"
        verbose_name = "Арга хэмжээ"
        verbose_name_plural = "Арга хэмжээнүүд"
