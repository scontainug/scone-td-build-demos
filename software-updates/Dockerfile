FROM python:3.11-slim

ARG VERSION=1
COPY print_env${VERSION}.py /app/print_env.py

WORKDIR /app
CMD ["/usr/local/bin/python3", "/app/print_env.py"]
