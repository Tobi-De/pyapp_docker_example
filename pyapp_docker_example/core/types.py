from django.http import HttpRequest as HttpRequestBase
from django_htmx.middleware import HtmxDetails
from pyapp_docker_example.users.models import User


class HttpRequest(HttpRequestBase):
    htmx: HtmxDetails


class AuthenticatedHttpRequest(HttpRequest):
    user: User
