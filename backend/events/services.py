
from django.db import connection, transaction


@transaction.atomic
def create_event(
    argahemjeeniidugaar,
    baiguulgiindugaar,
    angilaliindugaar,
    tulwiindugaar,
    garchig,
    tailbar,
    bairshil,
):
    # Шаардлагатай мэдээллийг шалгах
    if not argahemjeeniidugaar:
        raise ValueError("Арга хэмжээний дугаар шаардлагатай.")

    if not garchig or not garchig.strip():
        raise ValueError("Арга хэмжээний гарчиг шаардлагатай.")

    if not baiguulgiindugaar:
        raise ValueError("Байгууллага сонгоно уу.")

    if not angilaliindugaar:
        raise ValueError("Арга хэмжээний ангилал шаардлагатай.")

    if not tulwiindugaar:
        raise ValueError("Арга хэмжээний төлөв шаардлагатай.")

    if not bairshil or not bairshil.strip():
        raise ValueError("Арга хэмжээний байршил шаардлагатай.")

    # Одоо байгаа database-ийн хүснэгтэд хадгалах
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO argahemjee (
                argahemjeeniidugaar,
                baiguulgiindugaar,
                angilaliindugaar,
                tulwiindugaar,
                garchig,
                tailbar,
                bairshil
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            [
                argahemjeeniidugaar,
                baiguulgiindugaar,
                angilaliindugaar,
                tulwiindugaar,
                garchig.strip(),
                tailbar,
                bairshil.strip(),
            ],
        )

    return {
        "argahemjeeniidugaar": argahemjeeniidugaar,
        "garchig": garchig.strip(),
        "message": "Арга хэмжээ амжилттай бүртгэгдлээ.",
    }