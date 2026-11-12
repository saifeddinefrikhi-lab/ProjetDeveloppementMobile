export function notFound(req, _res, next) {
  const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
  error.status = 404;
  next(error);
}

export function errorHandler(error, req, res, _next) {
  const status = error.status || (error.code === 'ER_DUP_ENTRY' ? 409 : 500);
  if (status >= 500) console.error(error);
  res.status(status).json({ success: false, error: { message: status === 500 ? 'Internal server error' : error.message, ...(error.details ? { details: error.details } : {}) } });
}
