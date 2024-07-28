import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pyapp_docker_example.settings")

application = get_wsgi_application()
