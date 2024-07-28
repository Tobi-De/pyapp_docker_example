import multiprocessing
import os
import sys

from gunicorn.app import wsgiapp


def main() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pyapp_docker_example.settings")

    run_func = None
    if len(sys.argv) > 1:
        run_func = COMMANDS.get(sys.argv[1])

    if run_func:
        run_func(sys.argv)
    else:
        run_gunicorn(sys.argv)


def run_qcluster(argv: list) -> None:
    """Run Django-q cluster."""
    from django.core.management import execute_from_command_line

    execute_from_command_line(argv[2:])


def run_manage(argv: list) -> None:
    """Run Django's manage command."""
    from django.core.management import execute_from_command_line

    execute_from_command_line(argv[1:])


def run_gunicorn(argv) -> None:
    """
    Run gunicorn the wsgi server.
    https://docs.gunicorn.org/en/stable/settings.html
    https://adamj.eu/tech/2021/12/29/set-up-a-gunicorn-configuration-file-and-test-it/
    """

    workers = multiprocessing.cpu_count() * 2 + 1
    gunicorn_args = [
        "pyapp_docker_example.wsgi:application",
        "--bind",
        "127.0.0.1:8000",
        # "unix:/run/pyapp_docker_example.gunicorn.sock", # uncomment this line and comment the line above to use a socket file
        "--max-requests",
        "1000",
        "--max-requests-jitter",
        "50",
        "--workers",
        str(workers),
        "--access-logfile",
        "-",
        "--error-logfile",
        "-",
    ]
    argv.extend(gunicorn_args)
    wsgiapp.run()


COMMANDS = {"qcluster": run_qcluster, "manage": run_manage}


if __name__ == "__main__":
    main()
