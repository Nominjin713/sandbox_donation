"""Run the deployment WSGI server; hosting secrets come from the environment."""
import os

from django.core.management import call_command
from waitress import serve

os.environ.setdefault('DJANGO_DEBUG', 'false')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')


def main():
    from config.wsgi import application

    if os.environ.get('RUN_MIGRATIONS', 'true').lower() == 'true':
        call_command('migrate', interactive=False)
    serve(application, host='0.0.0.0', port=int(os.environ.get('PORT', '8080')),
          threads=4, channel_timeout=60)


if __name__ == '__main__':
    main()
