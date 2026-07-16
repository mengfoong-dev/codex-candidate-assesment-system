"""Uniform error envelope: every non-2xx body is {"error": {"code", "message"[, "details"]}}.

Centralizing this (Codex HIGH finding requires consistency across 404/409/422/500/503) means a
route just raises AppError(...) and the shape is guaranteed — no route hand-builds error JSON.
"""
from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

_STATUS_CODE = {
    400: "bad_request", 404: "not_found", 409: "conflict",
    422: "validation_error", 500: "internal_error", 503: "service_unavailable",
}


class AppError(Exception):
    """Raise anywhere in a route/service to return a clean error envelope."""

    def __init__(self, code: str, message: str, status_code: int = 400, details=None):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details
        super().__init__(message)


def _envelope(code: str, message: str, details=None) -> dict:
    err: dict = {"code": code, "message": message}
    if details is not None:
        err["details"] = jsonable_encoder(details)
    return {"error": err}


async def _app_error_handler(_: Request, exc: AppError):
    return JSONResponse(status_code=exc.status_code, content=_envelope(exc.code, exc.message, exc.details))


async def _http_exception_handler(_: Request, exc: StarletteHTTPException):
    code = _STATUS_CODE.get(exc.status_code, "error")
    return JSONResponse(status_code=exc.status_code, content=_envelope(code, str(exc.detail)))


async def _validation_handler(request: Request, exc: RequestValidationError):
    if request.url.path == "/api/chat":
        return JSONResponse(
            status_code=400,
            content=_envelope("bad_request", "Chat request validation failed", exc.errors()),
        )
    return JSONResponse(
        status_code=422,
        content=_envelope("validation_error", "Request validation failed", exc.errors()),
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppError, _app_error_handler)
    app.add_exception_handler(StarletteHTTPException, _http_exception_handler)
    app.add_exception_handler(RequestValidationError, _validation_handler)
