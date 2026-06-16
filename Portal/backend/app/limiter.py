"""Instancia compartida del rate limiter (slowapi)."""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Límite global por defecto: 200 req/min por IP.
# Los endpoints sensibles sobrescriben este valor con @limiter.limit("N/minute").
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])
