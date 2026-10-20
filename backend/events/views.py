from django.http import JsonResponse


def event_home(request):
    return JsonResponse({
        "message": "Арга хэмжээний app ажиллаж байна."
    })