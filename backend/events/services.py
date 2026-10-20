"""Validate and store events through the same model used by migrations."""
from django.db import transaction

from .models import Event


@transaction.atomic
def create_event(
    *, argahemjeeniidugaar, baiguullagiindugaar, angilaliindugaar,
    tulwiindugaar, garchig, bairshil, ehleh_ognoo, duusah_ognoo,
    oroltsohchdiin_too, tailbar='',
):
    event = Event(
        argahemjeeniidugaar=argahemjeeniidugaar,
        baiguullagiindugaar=baiguullagiindugaar,
        angilaliindugaar=angilaliindugaar,
        tulwiindugaar=tulwiindugaar,
        garchig=garchig.strip() if isinstance(garchig, str) else garchig,
        tailbar=tailbar,
        bairshil=bairshil.strip() if isinstance(bairshil, str) else bairshil,
        ehleh_ognoo=ehleh_ognoo,
        duusah_ognoo=duusah_ognoo,
        oroltsohchdiin_too=oroltsohchdiin_too,
    )
    event.full_clean()
    event.save(force_insert=True)
    return {
        'argahemjeeniidugaar': event.pk,
        'garchig': event.garchig,
        'message': 'Арга хэмжээ амжилттай бүртгэгдлээ.',
    }
